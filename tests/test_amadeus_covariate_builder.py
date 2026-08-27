import csv
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = REPO_ROOT / "amadeus_covariate_builder.py"
INPUT_PATH = REPO_ROOT / "data" / "az_county_diabetes_live.csv"

AMADEUS_REPO = Path(
    os.environ.get(
        "AMADEUS_REPO",
        REPO_ROOT.parent / "amadeus_ods",
    )
).resolve()


def read_csv_rows(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


class TestAmadeusCovariateBuilderIntegration(unittest.TestCase):

    def test_dry_run_uses_sample_csv_and_writes_manifest_bundle(self):
        input_rows = read_csv_rows(INPUT_PATH)

        with tempfile.TemporaryDirectory() as tmpdir:
            outdir = Path(tmpdir) / "amadeus_output"

            result = subprocess.run(
                [
                    sys.executable,
                    str(SCRIPT_PATH),
                    "--dry-run",
                    "--input-locations",
                    str(INPUT_PATH),
                    "--outdir",
                    str(outdir),
                    "--amadeus-repo",
                    str(AMADEUS_REPO),
                ],
                cwd=REPO_ROOT,
                check=False,
                text=True,
                capture_output=True,
            )

            self.assertEqual(
                result.returncode,
                0,
                msg=result.stderr,
            )

            manifest_path = (
                outdir
                / "input"
                / "selected_places_centroids.csv"
            )

            copied_input_path = (
                outdir
                / "input"
                / INPUT_PATH.name
            )

            metadata_path = (
                outdir
                / "metadata"
                / "metadata.json"
            )

            provenance_path = (
                outdir
                / "metadata"
                / "provenance.json"
            )

            qa_path = (
                outdir
                / "qa"
                / "qa_summary.md"
            )

            log_path = (
                outdir
                / "logs"
                / "run.log"
            )

            self.assertTrue(manifest_path.exists())
            self.assertTrue(copied_input_path.exists())
            self.assertTrue(metadata_path.exists())
            self.assertTrue(provenance_path.exists())
            self.assertTrue(qa_path.exists())
            self.assertTrue(log_path.exists())

            manifest_rows = read_csv_rows(manifest_path)

            self.assertEqual(
                len(manifest_rows),
                len(input_rows),
            )

            self.assertEqual(
                manifest_rows[0],
                {
                    "site_id": "az_county_04001",
                    "geo_level": "county",
                    "geoid": "04001",
                    "state": "AZ",
                    "lon": "-109.48881915611",
                    "lat": "35.3954681672691",
                    "selection_reason": (
                        "cdc_places_selected_geography"
                    ),
                },
            )

            self.assertIn(
                "Dry run: R workflow was not executed.",
                log_path.read_text(encoding="utf-8"),
            )

            self.assertIn(
                "input site count",
                qa_path.read_text(encoding="utf-8"),
            )


    @unittest.skipUnless(
        os.environ.get("RUN_AMADEUS_INTEGRATION") == "1",
        "Set RUN_AMADEUS_INTEGRATION=1 to run the live Amadeus integration test.",
    )
    def test_python_wrapper_runs_with_local_amadeus(self):

        self.assertTrue(
            AMADEUS_REPO.exists(),
            f"Local Amadeus repo not found: {AMADEUS_REPO}",
        )

        self.assertTrue(
            (AMADEUS_REPO / "DESCRIPTION").exists(),
            f"Invalid Amadeus package directory: {AMADEUS_REPO}",
        )

        self.assertIsNotNone(
            shutil.which("Rscript"),
            "Rscript is not available on PATH.",
        )

        output_dir = os.environ.get("OUTPUT_DIR")

        if output_dir:
            outdir = Path(output_dir) / "amadeus_output"
            outdir.mkdir(
                parents=True,
                exist_ok=True,
            )
            self._run_live_workflow(outdir)

        else:
            with tempfile.TemporaryDirectory() as tmpdir:
                outdir = Path(tmpdir) / "amadeus_output"
                self._run_live_workflow(outdir)


    def _run_live_workflow(self, outdir: Path) -> None:

        result = subprocess.run(
            [
                sys.executable,
                str(SCRIPT_PATH),
                "--input-locations",
                str(INPUT_PATH),
                "--outdir",
                str(outdir),
                "--amadeus-repo",
                str(AMADEUS_REPO),
            ],
            cwd=REPO_ROOT,
            check=False,
            text=True,
            capture_output=True,
        )

        self.assertEqual(
            result.returncode,
            0,
            msg=result.stderr,
        )

        extracted_path = (
            outdir
            / "raw"
            / "amadeus_extracted_raw.csv"
        )

        long_path = (
            outdir
            / "derived"
            / "amadeus_covariates_long.csv"
        )

        wide_path = (
            outdir
            / "derived"
            / "amadeus_covariates_wide.csv"
        )

        joined_path = (
            outdir
            / "joined"
            / "places_amadeus_joined_features.csv"
        )

        inventory_path = (
            outdir
            / "raw"
            / "amadeus_download_inventory.csv"
        )

        log_path = (
            outdir
            / "logs"
            / "run.log"
        )

        self.assertTrue(extracted_path.exists())
        self.assertTrue(long_path.exists())
        self.assertTrue(wide_path.exists())
        self.assertTrue(joined_path.exists())
        self.assertTrue(inventory_path.exists())
        self.assertTrue(log_path.exists())

        extracted_rows = read_csv_rows(extracted_path)

        self.assertGreater(
            len(extracted_rows),
            0,
        )

        self.assertEqual(
            list(extracted_rows[0].keys()),
            [
                "site_id",
                "time",
                "tmmx_0",
            ],
        )

        log_text = log_path.read_text(
            encoding="utf-8"
        )

        self.assertIn(
            str(AMADEUS_REPO),
            log_text,
        )

        self.assertIn(
            "Using local amadeus",
            log_text,
        )


if __name__ == "__main__":
    unittest.main()