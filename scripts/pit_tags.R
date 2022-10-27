#combining pit tag data to individual fish data so that we can copy and paste directly into submission template
# would be good to include the comments and times/camera of photos in the fish csv and then paste them to the right of the pit tag.

source('scripts/packages.R')

#import the pit tag csv
# because we are working in a project our working directory is the root folder so all paths are
# relative to that
# path <- '../../repo/dff-2022/data/pars/tag_01_01.csv'
path <- 'data/pars/tag_01_01.csv'
# path <- 'data/skeena/tag_01_02.csv'


# using readr is better than read.csv
# looks like tag_01_01 reads in with a column named tag but tag_01_02 does not have a column name
# for that reason the call to read_csv needs to be different (change col_names to F for that file).
# you will need to change the name of the column that gets seperated and the slice row below will not likely be necessary
pit_tag <- readr::read_csv(path, col_names = T) %>%
  #separate the pit tag out from the rest of the info in the pit tag csv
  # https://stackoverflow.com/questions/66696779/separate-by-pattern-word-in-tidyr-and-dplyr
  tidyr::separate(col=tag, into=c('date', 'tag_id'), sep='\\s*TAG\\s*') %>%
  tibble::rowid_to_column()


#import csv with fish data
path2 <- 'data/pars/fish_data.csv'

fish <- readr::read_csv(path2)

#join fish csv with pit tag csv based on tag row number
fish_tags <- dplyr::left_join(fish,
                              pit_tag,
                              by = c("tag_row" = "rowid")) %>%
  # arrange columns
  relocate(tag_id, .after = last_col()) %>%
  # remove the first row because it was from the office. We need to pass the object piped to nrow as a "."
  # as the first object gets passed to the slice function only
  dplyr::slice(1:nrow(.)) %>%
  # add a period, a space and the row number to the pit tag to go in the comments to make it easy to pull anything out we want later
  dplyr::mutate(tag_id = case_when(
    !is.na(tag_id) ~ paste0(tag_id, '. Row ID ', tag_row, '. '),
    T ~ tag_id))

# select a subsample of fish (lets go 15% since the sample size is small) to review manually to be sure the
# pit tags match which fish they go with
# set seed for reproducible sample - try running it again without setting the seed immediately before and see how it differs
set.seed(1234)
sample(nrow(fish_tags), nrow(fish_tags) * 0.15) %>%
  # arrange the row numbers to make it easier to QA
  sort()

# burn the csv ready to cut and paste
fish_tags %>%
  readr::write_csv('data/pars/fish_tags_joined.csv',
                   na = "" )


