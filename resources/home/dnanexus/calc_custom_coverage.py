#/usr/bin/python3

import os
import argparse
import pandas as pd

parser = argparse.ArgumentParser()
parser.add_argument('folder', type=str)
# parser.add_argument('coverage', type=int)
args = parser.parse_args()

# This script is pointed to a folder in a fixed location /calc_cov
folder = args.folder
# %coverage is calculated for the below depths
depths = [200,250,300,500,1000]

# Go through each file in the folder
# parse the files' section after ##HISTOGRAM into a dataframe
# then calculate target bases coverage of each sample and write to a file
with open("inp/custom_coverage.csv", 'w') as f:
    # Create header row: Sample,200x,250x,300x,500x,1000x
    cov_header = ",".join([str(i)+"x" for i in depths])
    header = ",".join(["Sample", cov_header])
    f.write(header + "\n")

    for file in os.listdir(folder):
        hs_data = pd.read_csv(folder+"/"+file, sep='\t', header=8,
            usecols=["coverage_or_base_quality", "high_quality_coverage_count"])
        total = sum(hs_data['high_quality_coverage_count'])

        # Calculate the coverage at each depth
        calc_cov = [sum(hs_data.loc[hs_data['coverage_or_base_quality']>=cov][
            'high_quality_coverage_count']) for cov in depths]

        # Calculate the %coverage at each depth
        p_cov = [cov/total*100 for cov in calc_cov]

        # Get the sample name by removing extentions
        fn = file.rstrip('.hsmetrics.tsv')
        if fn.endswith('.markdup') or fn.endswith('_markdup'):
            fn = fn[:-8]
        if fn.endswith('.sorted') or fn.endswith('_sorted'):
            fn = fn[:-7]
        if fn.endswith('.duplication') or fn.endswith('_duplication'
            ) or fn.endswith('.Duplication') or fn.endswith('_Duplication'):
            fn = fn[:-12]

        # Write %coverage at each depth 1 sample/row
        cov_line = ",".join([str(i) for i in p_cov])
        line = ",".join([fn, cov_line])
        f.write(line+"\n")

print("Done")
