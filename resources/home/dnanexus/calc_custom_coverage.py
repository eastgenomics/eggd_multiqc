# /usr/bin/python3
"""
    This script calculates percentage target bases coverage at custom depths
    Requires the pandas package (and dependencies) installed

    Expected inputs:
        - folder containing sample.hsmetrics.tsv files
        - comma-separated list of integer values of the depths
            at which coverage should be calculated

    Output:
        - custom_coverage.csv file in the inputs/ folder
            * has headings based on the input depths
            * config.yaml should have the same headings for
            data to be parsed correctly

    Sophie Ratkai 211105
"""

import os
import sys
import pandas as pd

# This script is pointed to a folder eg /hsmetrics_files
folder = sys.argv[1]
# %coverage is calculated at the depths provided by the user input
custom_depths = sys.argv[2]
depths = [int(x) for x in custom_depths.split(",")]

# Create header row: eg Sample,200x,250x,300x,500x,1000x
header = [str(i)+"x" for i in depths]
header.insert(0, "Sample")
custom_coverage = pd.DataFrame(columns=header)

extensions = ['markdup', 'sorted', 'duplication', 'Duplication']

# Go through each file in the folder
# parse the files' section after ##HISTOGRAM into a dataframe
# then calculate target bases coverage of each sample and write to a file
for file in os.listdir(folder):
    hs_metrics_file = "/".join([folder, file])
    hs_data = pd.read_csv(hs_metrics_file, sep='\t', header=8, index_col=False,
        usecols=["coverage_or_base_quality", "high_quality_coverage_count"]
    )
    # Get the sample name by removing extensions
    sample_name = file.rstrip('.hsmetrics.tsv')
    for ext in extensions:
        # remove any extensions from name prefixed with dot or underscore
        sample_name = sample_name.replace('.{}'.format(ext), '')
        sample_name = sample_name.replace('_{}'.format(ext), '')

    sample_info = {"Sample": sample_name}

    total = sum(hs_data["high_quality_coverage_count"])
    for depth in depths:  # list of integers
        # Sum the bases that are covered above 'depth'
        basecount_above_depth = sum(hs_data.loc[hs_data[
            "coverage_or_base_quality"] >= depth
            ]["high_quality_coverage_count"])
        # Calculate percentage coverage
        pct_coverage = basecount_above_depth / total * 100
        # Add percentage coverage to the dictionary with the key
        # matching the DataFrame column name
        depth_key = str(depth)+"x"
        sample_info[depth_key] = pct_coverage
    custom_coverage = custom_coverage.append(sample_info, ignore_index=True)

custom_coverage.to_csv("inputs/custom_coverage.csv",
    sep=',', encoding='utf-8', header=True, index=False)


print("Percentage coverage values were calculated for {} depths and saved to file: inputs/custom_coverage.csv".format(custom_depths))
