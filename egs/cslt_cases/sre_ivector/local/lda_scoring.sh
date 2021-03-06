#!/bin/bash
# Copyright 2015   David Snyder
#           2018   Tsinghua University (Author: Zhiyuan Tang)
# Apache 2.0.

# This script trains an LDA transform, applies it to the enroll and
# test i-vectors or d-vectors and does cosine scoring.

use_existing_models=false
lda_dim=150
covar_factor=0.1

echo "$0 $@"  # Print the command line for logging

if [ -f path.sh ]; then . ./path.sh; fi
. parse_options.sh || exit 1;

if [ $# != 8 ]; then
  echo "Usage: $0 <lda-data-dir> <enroll-data-dir> <test-data-dir> <lda-vec-dir> <enroll-vec-dir> <test-vec-dir> <trials-file> <scores-dir>"
fi

lda_data_dir=$1
enroll_data_dir=$2
test_data_dir=$3
lda_vec_dir=$4
enroll_vec_dir=$5
test_vec_dir=$6
trials=$7
scores_dir=$8

if [ "$use_existing_models" == "true" ]; then
  for f in ${lda_vec_dir}/mean.vec ${lda_vec_dir}/transform.mat ; do
    [ ! -f $f ] && echo "No such file $f" && exit 1;
  done
else

mkdir -p ${lda_vec_dir}/log
run.pl ${lda_vec_dir}/log/lda.log \
  ivector-compute-lda --dim=$lda_dim  --total-covariance-factor=$covar_factor \
  "ark:ivector-normalize-length scp:${lda_vec_dir}/vector.scp ark:- |" \
    ark:${lda_data_dir}/utt2spk \
    ${lda_vec_dir}/transform.mat || exit 1;
fi

mkdir -p $scores_dir/log
run.pl $scores_dir/log/lda_scoring.log \
  ivector-compute-dot-products  "cat '$trials' | cut -d\  --fields=1,2 |"  \
  "ark:ivector-transform ${lda_vec_dir}/transform.mat scp:${enroll_vec_dir}/spk_vector.scp ark:- | ivector-normalize-length ark:- ark:- |" \
  "ark:ivector-normalize-length scp:${test_vec_dir}/vector.scp ark:- | ivector-transform ${lda_vec_dir}/transform.mat ark:- ark:- | ivector-normalize-length ark:- ark:- |" \
  $scores_dir/lda_scores || exit 1;
