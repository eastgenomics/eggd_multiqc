# MultiQC (DNAnexus Platform App)

Uses the [MultiQC](https://multiqc.info/docs/) tool developed and maintained by Phil Ewels: [ewels/MultiQC](https://github.com/ewels/MultiQC/)

Docker images are available from [here](https://hub.docker.com/r/ewels/multiqc/)

## What does this app do?

This app downloads the quality metric files as specified by the location and filename extension in the "dx_sp" field in the config.yaml. Then runs the MultiQC tool to generate a run-wide quality report. Modules and columns to be displayed are specified in the config file, the full list of supported modules can be found [here](https://github.com/ewels/MultiQC/tree/v1.11/multiqc/modules).

It is essential to use a config file that has a "dx_sp" section with "primary" for file extenstions in app/outputs of the primary workflow and "secondary" for file extenstions in app/outputs of the secondary workflow.

## What inputs are required to run this app?

* `multiqc_docker`: Docker image of the MultiQC tool (can be found in 001_Reference:/assets/MultiQC)
* `multiqc_config_file`: A config.yaml file specifying which modules to run and the search patterns to recognise QC files for each module
* input data, which may come from different sources depending on the use-case
* `project_for_multiqc` - the name of the project to be used, eg 002_211008_A01303_0030_AHKTMYDRXY_TWE
* `primary_workflow_output` - the exact name of the output directory of the primary workflow, eg. dias_single_v1.2.3-TWE_v1.0.5-211011-1)
  * This folder must have subfolders for each app, like project:/output/primary_workflow/app_output)

Optional inputs:

* calc_custom_coverage: Boolean to indicate whether custom coverage needs to be computed and added to the multiqc report.
* depths: Depths to compute coverage for.

## What does this app output?

The following outputs are placed in the DNAnexus project in the specified output folder:

* a HTML QC report (with the name of the runfolder-workflow)
* a folder containing the qc metrics data in text format. (The folder is named after project-workflow-multiqc_data)
* original config_file.yaml that was used to generate the report

## How does this app work?

1. The app downloads files within the $project_for_multiQC:/output/$primary_workflow_output/QCapp directories of the project, where 'QCapp' and filename extensions are specified in the config file.
2. The app runs the dockerised MultiQC tool with the config file provided.
3. MultiQC parses all recognised files and displays them in the html report.
4. The MultiQC outputs are uploaded to DNAnexus.

## How to run this app from command line?

```bash
dx run multiqc-applet_ID \
-imultiqc_docker='{}' \
-imultiqc_config_file='{}' \
-iproject_for_multiqc='{}' \
-iprimary_workflow_output='{}' \
--destination='{}'
```

## This app was made by EMEE GLH
