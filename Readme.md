# MultiQC (DNAnexus Platform App)

multiqc
forked from ewels/MultiQC [v1.8](https://github.com/ewels/MultiQC/)
East GLH fork of MultiQC (https://github.com/eastgenomics/MultiQC/)

## What does this app do?
This app runs the East GLH fork of MultiQC to generate run wide quality control (QC) using the outputs from 'our' pipelines including:
* VCFeval Hap.py - SNP and INDEL values are split into separate tables
* Het-hom analysis
* Verifybamid
* Sentieon-dnaseq and Picard
* Samtools/flagstat and
* FastQC 

## What are the typical use cases for this app?
To visualise QC reports, this app should be run at the end of an NGS pipeline, when all QC software outputs are available.

## What data are required for this app to run?
* project_for_multiQC - The name of the project to be assessed. (like 002_200430_DiasBatch)
  * This project must have an 'output' folder in its root directory.
* single_sample_workflow_for_multiQC - The exact name of a ss run. (like dias_v1.0.0-200430-1) 
  * This folder must have subfolders for each QC app. (like run/verifybamid or run/fastqc)
* multi_sample_workflow_for_multiQC - The exact name of a ms run. (like multi_v1.0.0-200430-1) 
* config_file.yaml - A config file specifying which modules to run and the search pattern to recognise qc files for each module

## What does this app output?
The following outputs are placed in the DNAnexus project:
* A HTML QC report (with the name of the runfolder)
* A folder containing the output in text format. (folder named after run-multiqc_data)

## How does this app work?
1. The app downloads all files within all the $project_for_multiQC/output/$run_for_multiQC/QCapp directory of the project. 
2. A config file is used to search for files with specific name patterns, which are downloaded if found.
3. The app uses a modified version of MultiQC v1.8. This differs from the official release only in the addition of a Sentieon module that parses the Sentieon-dnaseq QC files (equivalent to the Picard modules of the same name). The forked repo is held at github.com/eastgenomics/MultiQC and the commit used is dec2e93. The custom modules are installed using pip v20.1.
4. MultiQC parses all recognised files and includes them in the report.
5. The MultiQC outputs are uploaded to DNAnexus.

## This app was made by EMEE GLH