# MultiQC (DNAnexus Platform App)

multiqc
using ewels/MultiQC [v1.11](https://github.com/ewels/MultiQC/tree/v1.11)
Docker image avaialable here: https://hub.docker.com/r/ewels/multiqc/tags v1.11

## What are the typical use cases for this app?
To visualise QC reports this app should be run at the end of an NGS pipeline when all QC software outputs are available.

## What data are required for this app to run?
* config_file.yaml - A config file specifying which modules to run and the search patterns to recognise QC files for each module
* optional to calculate target bases coverage at 200x, 250x, 300x, 500x, 1000x
* input data, which may come from different sources:
Option 1 for production run on workflow output:
* *project_for_multiqc* - The name of the project to be used. (like 002_211008_A01303_0030_AHKTMYDRXY_TWE)
  - This project must have an 'output' folder in its root directory (project:/output/).
* *single_sample_workflow_for_multiqc* - The exact name of a ss run. (like dias_single_v1.2.3-TWE_v1.0.5-211011-1) 
  - This folder must have subfolders for each app. (like project:/output/workflow/app_output)
* *multi_sample_workflow_for_multiqc* - The exact name of a ms run. (like project:/output/workflow/multi/happy) OPTIONAL

Option 2 for testing and development:
* set the single_folder input option to TRUE and provide a
* project name and 
* the absolut path to a specific folder in the project with all QC files
For example, if you want files from project:/folder/subfolder/data_files, you need to input 'folder/subfolder' into the field
This will download all files from only this folder and will break if there are further subfolders inside!

The qc metrics to be displayed in the report are specified by location and filename extension in the config.yaml under the "dx_sp" tag. It is essential to use a config file that has this section!!

## What does this app do?
This app runs MultiQC v1.11 tool to generate run-wide quality report using the outputs from the pipeline. Modules included are specified in the config file, the list of supported modules can be found [here] (https://github.com/ewels/MultiQC/tree/v1.11/multiqc/modules).

## What does this app output?
The following outputs are placed in the DNAnexus project in the specified folder:
* a HTML QC report (with the name of the runfolder-workflow)
* a folder containing the qc metrics data in text format. (The folder is named after project-workflow-multiqc_data)
* original config_file.yaml that was used to generate the report

## How does this app work?
1. The app downloads files within the $project_for_multiQC:/output/$ss_for_multiQC/QCapp directories of the project, where 'QCapp' and filename extensions are specified in the config file.
2. The app runs the dockerised MultiQC v1.11 tool with the config file provided.
3. MultiQC parses all recognised files and displays them in the report.
4. The MultiQC outputs are uploaded to DNAnexus.

## How to run this app from command line?
dx run multiqc-applet_ID \
-ieggd_multiqc_config_file='{}' \
-iproject_for_multiqc='{}' \
-iss_for_multiqc='{}' \
-ims_for_multiqc='{}' \
--destination='{}'

## How was the Docker image created?
docker pull ewels/multiqc:v1.11
docker save ewels/multiqc:v1.11 | gzip > multiqc_v1.11.tar.gz

## This app was made by EMEE GLH
