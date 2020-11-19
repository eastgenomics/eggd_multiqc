import os
import argparse
import pandas as pd

parser = argparse.ArgumentParser()
parser.add_argument('folder', type=str)
# parser.add_argument('coverage', type=int)
args = parser.parse_args()

# This script is pointed to a folder in a fixed location /calc_cov
folder = args.folder
#print("folder {}".format(folder))
# also takes a single int value as an input
# coverage = args.coverage
#print("coverage {}".format(coverage))

# Go through each file in the folder, parse the files' section after ##something into a dataframe
    # then calculate target bases coverage of each sample and write to a file
with open("inp/custom_coverage.csv", 'w') as ccc:
    # Create header row
    ccc.write("Sample,200x,250x,300x,500x,1000x\n")
    for file in os.listdir(folder):
        hs_data = pd.read_csv(folder+"/"+file, sep='\t', header=8,
                          usecols=["coverage_or_base_quality", "high_quality_coverage_count"])
        total = sum(hs_data['high_quality_coverage_count'])
        # Calculate the coverage at each depth
        x200x = sum(hs_data.loc[hs_data['coverage_or_base_quality']>=200]['high_quality_coverage_count'])
        x250x = sum(hs_data.loc[hs_data['coverage_or_base_quality']>=250]['high_quality_coverage_count'])
        x300x = sum(hs_data.loc[hs_data['coverage_or_base_quality']>=300]['high_quality_coverage_count'])
        x500x = sum(hs_data.loc[hs_data['coverage_or_base_quality']>=500]['high_quality_coverage_count'])
        x1000x = sum(hs_data.loc[hs_data['coverage_or_base_quality']>=1000]['high_quality_coverage_count'])
        # Calculate the %coverage at each depth
        p200 = x200x/total*100
        p250 = x250x/total*100
        p300 = x300x/total*100
        p500 = x500x/total*100
        p1000 = x1000x/total*100
        # Get the sample name
        fn = file.rstrip('.hsmetrics.tsv')
        if fn.endswith('.markdup') or fn.endswith('_markdup'):
            fn = fn[:-8]
        if fn.endswith('.sorted') or fn.endswith('_sorted'):
            fn = fn[:-7]
        if fn.endswith('.duplication') or fn.endswith('_duplication') or fn.endswith('.Duplication') or fn.endswith('_Duplication'):
            fn = fn[:-12]
        # Write %coverage at each depth 1 sample/row
        line = "{},{},{},{},{},{}".format(fn, p200, p250, p300, p500, p1000)
        ccc.write(line+"\n")
print("Done")
