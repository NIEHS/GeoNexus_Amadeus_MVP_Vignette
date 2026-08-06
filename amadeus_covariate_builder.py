#!/usr/bin/env python3
"""Run the Amadeus covariate builder workflow for a small point manifest."""

from __future__ import annotations

import argparse
import csv
import json
import os
import shutil
import subprocess
import sys
from collections import defaultdict
from datetime import UTC, datetime
from pathlib import Path


WORKFLOW_NAME = "amadeus-covariate-builder"
WORKFLOW_VERSION = "0.1.0"
MANIFEST_FIELDS = [
    "site_id",
    "geo_level",
    "geoid",
    "state",
    "lon",
    "lat",
    "selection_reason",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Normalize a CDC PLACES-derived CSV into an Amadeus location manifest, "
            "run the Amadeus gridMET workflow, and write the MVP output bundle."
        )
    )
    parser.add_argument(
        "--input-locations",
        default="data/az_county_diabetes_live.csv",
        help="Input CSV. Defaults to the sample file in this repo.",
    )
    parser.add_argument(
        "--location-id-column",
        default="site_id",
        help="Location identifier column expected by the Amadeus run.",
    )
    parser.add_argument(
        "--longitude-column",
        default="lon",
        help="Longitude column in the normalized manifest.",
    )
    parser.add_argument(
        "--latitude-column",
        default="lat",
        help="Latitude column in the normalized manifest.",
    )
    parser.add_argument(
        "--covariate-dataset",
        default="gridmet",
        help="Amadeus dataset name. MVP default is gridmet.",
    )
    parser.add_argument(
        "--covariate-variable",
        default="tmmx",
        help="Amadeus variable code. MVP default is tmmx.",
    )
    parser.add_argument("--start-date", default="2022-07-01")
    parser.add_argument("--end-date", default="2022-07-07")
    parser.add_argument(
        "--summary-statistic",
        default="mean",
        help="Cell-summary function passed to Amadeus. MVP default is mean.",
    )
    parser.add_argument(
        "--buffer-radius-m",
        type=int,
        default=0,
        help="Extraction buffer radius in meters. Use 0 for point extraction.",
    )
    parser.add_argument(
        "--outdir",
        default="amadeus_covariate_builder_output",
        help="Output bundle directory.",
    )
    parser.add_argument(
        "--output-prefix",
        default="amadeus_demo",
        help="Prefix stored in metadata and provenance.",
    )
    parser.add_argument(
        "--amadeus-repo",
        default="../amadeus",
        help="Path to a local amadeus checkout for pkgload fallback.",
    )
    parser.add_argument(
        "--rscript-bin",
        default="Rscript",
        help="Rscript executable used to run the Amadeus workflow.",
    )
    parser.add_argument(
        "--geo-level",
        default="county",
        help="Geo level to use when the input CSV does not include one.",
    )
    parser.add_argument(
        "--selection-reason",
        default="cdc_places_selected_geography",
        help="Fallback selection_reason value when the input CSV does not include one.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Prepare normalized inputs and output folders without calling R.",
    )
    return parser.parse_args()


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv_rows(path: Path, rows: list[dict[str, object]], fieldnames: list[str]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def infer_site_id(state: str, geo_level: str, geoid: str) -> str:
    return f"{state.lower()}_{geo_level}_{geoid}"


def normalize_input_rows(rows: list[dict[str, str]], args: argparse.Namespace) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    normalized = []
    passthrough = []

    for row in rows:
        state = (row.get("state") or row.get("stateabbr") or "").strip()
        geoid = (row.get("geoid") or row.get("countyfips") or row.get("locationid") or "").strip()
        lon = (row.get("lon") or row.get(args.longitude_column) or "").strip()
        lat = (row.get("lat") or row.get(args.latitude_column) or "").strip()
        geo_level = (row.get("geo_level") or args.geo_level).strip()
        site_id = (row.get(args.location_id_column) or row.get("site_id") or "").strip()
        if not site_id:
            site_id = infer_site_id(state=state, geo_level=geo_level, geoid=geoid)
        selection_reason = (row.get("selection_reason") or args.selection_reason).strip()

        missing = [
            name
            for name, value in (
                ("state", state),
                ("geoid", geoid),
                ("lon", lon),
                ("lat", lat),
            )
            if not value
        ]
        if missing:
            raise ValueError(f"Input row is missing required fields after normalization: {', '.join(missing)}")

        manifest_row = {
            "site_id": site_id,
            "geo_level": geo_level,
            "geoid": geoid,
            "state": state,
            "lon": lon,
            "lat": lat,
            "selection_reason": selection_reason,
        }
        normalized.append(manifest_row)

        passthrough_row = dict(row)
        passthrough_row.update(manifest_row)
        passthrough.append(passthrough_row)

    return normalized, passthrough


def make_output_dirs(outdir: Path) -> dict[str, Path]:
    paths = {
        "root": outdir,
        "input": outdir / "input",
        "raw": outdir / "raw",
        "derived": outdir / "derived",
        "joined": outdir / "joined",
        "metadata": outdir / "metadata",
        "qa": outdir / "qa",
        "logs": outdir / "logs",
    }
    for path in paths.values():
        path.mkdir(parents=True, exist_ok=True)
    return paths


def run_r_workflow(
    args: argparse.Namespace,
    manifest_path: Path,
    raw_dir: Path,
    extracted_out: Path,
    log_path: Path,
) -> None:
    script_path = Path(__file__).resolve().with_suffix(".R")
    cmd = [
        args.rscript_bin,
        str(script_path),
        str(manifest_path),
        args.covariate_dataset,
        args.covariate_variable,
        args.start_date,
        args.end_date,
        args.summary_statistic,
        str(args.buffer_radius_m),
        str(raw_dir),
        str(extracted_out),
        str(Path(args.amadeus_repo).resolve()),
    ]
    result = subprocess.run(
        cmd,
        check=False,
        text=True,
        capture_output=True,
    )
    log_path.write_text(
        "\n".join(
            [
                f"Command: {' '.join(cmd)}",
                "",
                "STDOUT:",
                result.stdout,
                "",
                "STDERR:",
                result.stderr,
            ]
        ),
        encoding="utf-8",
    )
    if result.returncode != 0:
        raise RuntimeError(
            f"Amadeus R workflow failed with exit code {result.returncode}. "
            f"See log: {log_path}"
        )


def read_extracted_rows(path: Path) -> list[dict[str, str]]:
    rows = read_csv_rows(path)
    if not rows:
        raise ValueError(f"No Amadeus covariate rows were produced: {path}")
    return rows


def infer_value_column(rows: list[dict[str, str]]) -> str:
    reserved = {"site_id", "time", "geometry"}
    candidates = [name for name in rows[0].keys() if name not in reserved]
    if len(candidates) == 1:
        return candidates[0]
    radius_candidates = [name for name in candidates if name.endswith("_0")]
    if len(radius_candidates) == 1:
        return radius_candidates[0]
    raise ValueError(f"Unable to infer a single Amadeus value column from: {candidates}")


def build_long_rows(
    manifest_rows: list[dict[str, str]],
    extracted_rows: list[dict[str, str]],
    args: argparse.Namespace,
) -> list[dict[str, object]]:
    manifest_by_site = {row["site_id"]: row for row in manifest_rows}
    value_column = infer_value_column(extracted_rows)
    long_rows = []
    for row in extracted_rows:
        manifest = manifest_by_site[row["site_id"]]
        long_rows.append(
            {
                "site_id": row["site_id"],
                "geo_level": manifest["geo_level"],
                "geoid": manifest["geoid"],
                "state": manifest["state"],
                "covariate_dataset": args.covariate_dataset,
                "covariate_variable": args.covariate_variable,
                "start_date": args.start_date,
                "end_date": args.end_date,
                "summary_statistic": args.summary_statistic,
                "time": row.get("time", ""),
                "value": row[value_column],
                "unit": "",
                "buffer_radius_m": args.buffer_radius_m,
                "workflow_name": WORKFLOW_NAME,
                "workflow_version": WORKFLOW_VERSION,
            }
        )
    return long_rows


def build_wide_rows(
    manifest_rows: list[dict[str, str]],
    passthrough_rows: list[dict[str, str]],
    long_rows: list[dict[str, object]],
    args: argparse.Namespace,
) -> tuple[list[str], list[dict[str, object]]]:
    values_by_site: dict[str, list[float]] = defaultdict(list)
    for row in long_rows:
        if row["value"] not in ("", None):
            values_by_site[row["site_id"]].append(float(row["value"]))

    summary_column = (
        f"amadeus_{args.covariate_dataset}_{args.covariate_variable}_"
        f"{args.summary_statistic}_{args.start_date.replace('-', '')}_{args.end_date.replace('-', '')}"
    )

    manifest_by_site = {row["site_id"]: row for row in manifest_rows}
    passthrough_by_site = {row["site_id"]: row for row in passthrough_rows}
    passthrough_fields = list(passthrough_rows[0].keys()) if passthrough_rows else []

    wide_rows = []
    for site_id, manifest in manifest_by_site.items():
        row = {field: passthrough_by_site[site_id].get(field, "") for field in passthrough_fields}
        row.update(manifest)
        site_values = values_by_site.get(site_id, [])
        row[summary_column] = (
            round(sum(site_values) / len(site_values), 6) if site_values else ""
        )
        wide_rows.append(row)

    fieldnames = list(dict.fromkeys(passthrough_fields + MANIFEST_FIELDS + [summary_column]))
    return fieldnames, wide_rows


def build_download_inventory(raw_dir: Path) -> list[dict[str, object]]:
    rows = []
    for file_path in sorted(path for path in raw_dir.rglob("*") if path.is_file()):
        rows.append(
            {
                "relative_path": str(file_path.relative_to(raw_dir)),
                "size_bytes": file_path.stat().st_size,
            }
        )
    return rows


def write_metadata(
    metadata_dir: Path,
    args: argparse.Namespace,
    input_path: Path,
    output_dirs: dict[str, Path],
    manifest_rows: list[dict[str, str]],
) -> None:
    metadata = {
        "workflow_name": WORKFLOW_NAME,
        "workflow_version": WORKFLOW_VERSION,
        "generated_at_utc": datetime.now(UTC).isoformat(),
        "input_locations": str(input_path),
        "covariate_dataset": args.covariate_dataset,
        "covariate_variable": args.covariate_variable,
        "start_date": args.start_date,
        "end_date": args.end_date,
        "summary_statistic": args.summary_statistic,
        "buffer_radius_m": args.buffer_radius_m,
        "site_count": len(manifest_rows),
        "output_prefix": args.output_prefix,
    }
    provenance = {
        "input_manifest": str(output_dirs["input"] / "selected_places_centroids.csv"),
        "raw_inventory": str(output_dirs["raw"] / "amadeus_download_inventory.csv"),
        "covariates_long": str(output_dirs["derived"] / "amadeus_covariates_long.csv"),
        "covariates_wide": str(output_dirs["derived"] / "amadeus_covariates_wide.csv"),
        "joined_features": str(output_dirs["joined"] / "places_amadeus_joined_features.csv"),
        "run_log": str(output_dirs["logs"] / "run.log"),
        "amadeus_repo": str(Path(args.amadeus_repo).resolve()),
    }
    (metadata_dir / "metadata.json").write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    (metadata_dir / "provenance.json").write_text(json.dumps(provenance, indent=2), encoding="utf-8")


def write_qa_summary(
    qa_dir: Path,
    manifest_rows: list[dict[str, str]],
    long_rows: list[dict[str, object]],
    wide_rows: list[dict[str, object]],
) -> None:
    missing_coords = sum(1 for row in manifest_rows if not row["lon"] or not row["lat"])
    summary = "\n".join(
        [
            "# QA Summary",
            "",
            f"- input site count: {len(manifest_rows)}",
            f"- long table row count: {len(long_rows)}",
            f"- wide table row count: {len(wide_rows)}",
            f"- locations missing lon/lat after normalization: {missing_coords}",
        ]
    )
    (qa_dir / "qa_summary.md").write_text(summary, encoding="utf-8")


def main() -> int:
    args = parse_args()
    repo_root = Path(__file__).resolve().parent
    input_path = (repo_root / args.input_locations).resolve() if not Path(args.input_locations).is_absolute() else Path(args.input_locations)
    outdir = (repo_root / args.outdir).resolve() if not Path(args.outdir).is_absolute() else Path(args.outdir)

    if not input_path.exists():
        raise FileNotFoundError(f"Input CSV not found: {input_path}")
    if shutil.which(args.rscript_bin) is None and not args.dry_run:
        raise FileNotFoundError(f"Rscript executable not found: {args.rscript_bin}")

    source_rows = read_csv_rows(input_path)
    if not source_rows:
        raise ValueError(f"Input CSV is empty: {input_path}")

    manifest_rows, passthrough_rows = normalize_input_rows(source_rows, args)
    output_dirs = make_output_dirs(outdir)

    manifest_path = output_dirs["input"] / "selected_places_centroids.csv"
    write_csv_rows(manifest_path, manifest_rows, MANIFEST_FIELDS)
    shutil.copy2(input_path, output_dirs["input"] / input_path.name)

    extracted_path = output_dirs["raw"] / "amadeus_extracted_raw.csv"
    log_path = output_dirs["logs"] / "run.log"

    if args.dry_run:
        log_path.write_text("Dry run: R workflow was not executed.\n", encoding="utf-8")
        extracted_rows = []
        long_rows = []
        wide_rows = []
        wide_fields = MANIFEST_FIELDS
    else:
        run_r_workflow(args, manifest_path, output_dirs["raw"], extracted_path, log_path)
        extracted_rows = read_extracted_rows(extracted_path)
        long_rows = build_long_rows(manifest_rows, extracted_rows, args)
        wide_fields, wide_rows = build_wide_rows(manifest_rows, passthrough_rows, long_rows, args)

        write_csv_rows(
            output_dirs["derived"] / "amadeus_covariates_long.csv",
            long_rows,
            [
                "site_id",
                "geo_level",
                "geoid",
                "state",
                "covariate_dataset",
                "covariate_variable",
                "start_date",
                "end_date",
                "summary_statistic",
                "time",
                "value",
                "unit",
                "buffer_radius_m",
                "workflow_name",
                "workflow_version",
            ],
        )
        write_csv_rows(
            output_dirs["derived"] / "amadeus_covariates_wide.csv",
            wide_rows,
            wide_fields,
        )
        write_csv_rows(
            output_dirs["joined"] / "places_amadeus_joined_features.csv",
            wide_rows,
            wide_fields,
        )

        inventory_rows = build_download_inventory(output_dirs["raw"])
        write_csv_rows(
            output_dirs["raw"] / "amadeus_download_inventory.csv",
            inventory_rows,
            ["relative_path", "size_bytes"],
        )

    write_metadata(output_dirs["metadata"], args, input_path, output_dirs, manifest_rows)
    write_qa_summary(output_dirs["qa"], manifest_rows, long_rows, wide_rows)

    print(f"Wrote output bundle to {outdir}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(1)
