#!/bin/bash
#
#SBATCH --partition=prioritized
#SBATCH --job-name=preprocess
#SBATCH --output=%j.out
#SBATCH --time=30:00:00
#SBATCH --mem=256GB

inputfolder=$1
outputfolder=$2


source $HOME/.bashrc
conda activate mg

cd $HOME/ColexPhon

python src/preprocessing/get_colex_langs.py "$inputfolder" "$outputfolder"

