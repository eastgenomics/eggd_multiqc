# eggd_multiqc (DNAnexus Platform App)

multiqc
ewels/MultiQC [v1.8](https://github.com/ewels/MultiQC/)

## What does this app do?
This app runs MultiQC to generate run wide quality control (QC) using the outputs from 'our' pipelines including:
* FastQC 
* verifybamid
* samtools/flagstat
* sentieonPicard

## What are the typical use cases for this app?
To visualise QC reports, this app should be run at the end of an NGS pipeline, when all QC software outputs are available.

## What data are required for this app to run?
* project_for_multiQC - The name of the project to be assessed. (like 002_###)
  * This project must have an 'output' folder in its root directory.
* workflow_for_multiQC - The exact name of a run. (like Dias_date_1) 
  * This folder must have subfolders for each QC app.
* config_file.yaml - A config file specifying which modules to run and the search pattern to recognise for each module
* tarball of the docker image for MultiQC 1.8 (sits in 001/assets/)

## What does this app output?
The following outputs are placed in the DNAnexus project under '/QC/multiqc':
* A HTML QC report (with the name of the runfolder) which should be uploaded to the ## server.
* A folder containing the output in text format.

## How does this app work?
1. The app downloads all files within the output/workflow/app directory of the project. 
2. A config file is used to search for files with specific name patterns, which are downloaded if found.
3. A dockerised version of MultiQC is used. The docker image is stored on DNAnexus as an asset, which is bundled with the app build. The following commands were used to generate this asset in a cloud workstation:
    * `docker pull ewels/multiqc:1.8`
    * `dx-docker create-asset ewels/multiqc:1.8`
    * The asset on DNAnexus was then renamed with the following command: `dx mv ewels\\multiqc\\:1.8 ewels_multiqc_1.8`
4. MultiQC parses all files, including any recognised files in the report.
5. The MultiQC outputs are uploaded to DNAnexus.