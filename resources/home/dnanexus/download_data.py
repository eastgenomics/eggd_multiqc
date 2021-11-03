# /usr/bin/python3

import os
import sys
import json

config_json = open("config.json", 'r')
config = json.load(config_json)

workflowdir = sys.argv[1]
for module in config["primary"]:
    # folder = module.split('/')[0]
    # path = workflowdir+'/*'+folder+'*'
    for fname in config["primary"][module]:
        os.system("dx find data --brief --path {} --name {} | \
            parallel -I% 'dx download % -o ./inp/'".format(workflowdir, fname))
        print("downloaded {} files".format(fname))

try:
    secondary_workflow = sys.argv[2]
    for module in config["secondary"]:
        # folder = module.split('/')[0]
        path = workflowdir+'/'+secondary_workflow
        for fname in config["secondary"][module]:
            os.system("dx find data --brief --path {} --name {} | \
                parallel -I% 'dx download % -o ./inp/'".format(path, fname))
            print("downloaded {} files".format(fname))
except:
    print("No secondary workflow provided")
