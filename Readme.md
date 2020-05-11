# eggd_multiqc (DNAnexus Platform App)

multiqc
ewels/MultiQC [v1.8](https://github.com/ewels/MultiQC/)

## What does this app do?
This app runs MultiQC to generate run wide quality control (QC) using the outputs from 'our' pipelines including:
* Het-hom analysis
* Verifybamid
* sentieonPicard and Picard
* samtools/flagstat and
* FastQC 

## What are the typical use cases for this app?
To visualise QC reports, this app should be run at the end of an NGS pipeline, when all QC software outputs are available.

## What data are required for this app to run?
* project_for_multiQC - The name of the project to be assessed. (like 002_200430_DiasBatch)
  * This project must have an 'output' folder in its root directory.
* run_for_multiQC - The exact name of a run. (like dias_v1.0.0-200430-1) 
  * This folder must have subfolders for each QC app. (like run/verifybamid or run/fastqc)
* config_file.yaml - A config file specifying which modules to run and the search pattern to recognise qc files for each module

## What does this app output?
The following outputs are placed in the DNAnexus project under '/QC/multiqc':
* A HTML QC report (with the name of the runfolder)
* A folder containing the output in text format. (folder named after run-multiqc_data)

## How does this app work?
1. The app downloads all files within all the $project_for_multiQC/output/$run_for_multiQC/QCapp directory of the project. 
2. A config file is used to search for files with specific name patterns, which are downloaded if found.
3. A dockerised version of MultiQC is used. The docker image is stored on DNAnexus as an asset, which is bundled with the app build. The following commands were used to generate this asset in a cloud workstation:
    * `docker pull ewels/multiqc:1.8`
    * `dx-docker create-asset ewels/multiqc:1.8`
    * The asset on DNAnexus was then renamed with the following command: `dx mv ewels\\multiqc\\:1.8 ewels_multiqc_1.8`
4. MultiQC parses all files, including any recognised files in the report.
5. The MultiQC outputs are uploaded to DNAnexus.