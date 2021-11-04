# /usr/bin/python3

import sys
import json
import subprocess

workflowdir = sys.argv[1]

with open("config.json", 'r') as config_json:
    config = json.load(config_json)

    for module in config["primary"]:
        # folder = module.split('/')[0]
        # path = workflowdir+'/*'+folder+'*'
        for fname in config["primary"][module]:
            subprocess.run("dx find data --brief --path {} --name {} | parallel -I% 'dx download % -o ./inp/'".format(workflowdir, fname), shell=True)
            print("downloaded {} files".format(fname))

    if sys.argv[2]:
        secondary_workflow = sys.argv[2]
        for module in config["secondary"]:
            # folder = module.split('/')[0]
            path = workflowdir+'/'+secondary_workflow
            for fname in config["secondary"][module]:
                subprocess.run("dx find data --brief --path {} --name {} | parallel -I% 'dx download % -o ./inp/'".format(path, fname), shell=True)
                print("downloaded {} files".format(fname))
    else:
        print("No secondary workflow provided")
