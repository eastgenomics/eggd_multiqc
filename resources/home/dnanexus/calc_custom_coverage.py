import os
import argparse
import pandas as pd

parser = argparse.ArgumentParser()
parser.add_argument('folder', type=str)
parser.add_argument('coverage', type=int)
args = parser.parse_args()

# This script is pointed to a folder in a fixed location /calc_cov
folder = args.folder
#print("folder {}".format(folder))
# also takes a single int value as an input
coverage = args.coverage
#print("coverage {}".format(coverage))

# Go through each file in the folder, parse the files' section after ##something into a dataframe
    # then calculate target bases coverage of each sample and write to a file
with open("inp/custom_coverage_"+str(coverage)+"x_mqc.csv", 'w') as cc:
    cc.write("Sample,percentage"+"\n")
    for file in os.listdir(folder):
        hs_data = pd.read_csv(folder+"/"+file, sep='\t', header=8,
                          usecols=["coverage_or_base_quality", "high_quality_coverage_count"])
        total = sum(hs_data['high_quality_coverage_count'])
        selected = sum(hs_data.loc[hs_data['coverage_or_base_quality']>=coverage]['high_quality_coverage_count'])
        percentage = selected/total*100
        fn = file.rstrip('.hsmetrics.tsv')
        if fn.endswith('.markdup') or fn.endswith('_markdup'):
            fn = fn[:-8]
        if fn.endswith('.sorted') or fn.endswith('_sorted'):
            fn = fn[:-7]
        if fn.endswith('.duplication') or fn.endswith('_duplication') or fn.endswith('.Duplication') or fn.endswith('_Duplication'):
            fn = fn[:-12]
        
        line = "{},{:.2f}".format(fn, percentage)
        cc.write(line+"\n")
print("Done")







