# Source - https://stackoverflow.com/a/48880959
# Posted by knish, modified by community. See post 'Timeline' for change history
# Retrieved 2026-08-07, License - CC BY-SA 3.0

library("argparser")
parser <- arg_parser(description='Process commandline arguments')
parser <- add_argument(parser, arg="--dataset", type="character", help = "Dataset argument")
args = parse_args(parser)
args_file = "tempArgObjectFile.rds"
saveRDS(args, args_file); print(args); quit(); #comment this after creating args_file
args = readRDS(args_file)  #use this to load during interactive development
