#/usr/bin/python3

import os
import argparse
import json

parser = argparse.ArgumentParser()
parser.add_argument('workflowdir', type=str)
parser.add_argument('--multi', type=str)

args = parser.parse_args()
workflowdir = args.workflowdir
multi = args.multi

config_json = open("config.json", 'r')
config = json.load(config_json)
# print(type(config["single"]))
for module in config["primary"]:
    # folder = module.split('/')[0]
    # path = workflowdir+'/*'+folder+'*'
    for fname in config["primary"][module]:
        os.system("dx find data --brief --path {} --name {} | \
            parallel -I% 'dx download % -o ./inp/'".format(workflowdir, fname))
        print("downloaded {} files".format(fname))

try:
    for module in config["secondary"]:
        # folder = module.split('/')[0]
        path = workflowdir+'/'+multi
        for fname in config["secondary"][module]:
            os.system("dx find data --brief --path {} --name {} | \
                parallel -I% 'dx download % -o ./inp/'".format(path, fname))
            print("downloaded {} files".format(fname))
except:
    pass
