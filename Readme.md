# MultiQC (DNAnexus Platform App)

multiqc
forked from ewels/MultiQC [v1.9](https://github.com/ewels/MultiQC/)
East GLH fork of MultiQC (https://github.com/eastgenomics/MultiQC/tree/eggd_multiqc) eggd_multiqc branch has been dockerised
Docker image avaialable here: https://hub.docker.com/repository/docker/sophie22/multiqc_egg

## What are the typical use cases for this app?
To visualise QC reports, this app should be run at the end of an NGS pipeline, when all QC software outputs are available.

## What data are required for this app to run?
* config_file.yaml - A config file specifying which modules to run and the search patterns to recognise QC files for each module
* input data, may come from different sources:
Option 1 for testing and development:
* project name and a 
* specific folder (or subfolder) in the project with all QC output

Option 2 for production run on workflow output:
* *project_for_multiQC* - The name of the project to be assessed. (like 002_200430_DiasBatch)
  - This project must have an 'output' folder in its root directory.
* *single_sample_workflow_for_multiQC* - The exact name of a ss run. (like dias_v1.0.0-200430-1) 
  - This folder must have subfolders for each QC app. (like ss/verifybamid or ss/fastqc)
* *multi_sample_workflow_for_multiQC* - The exact name of a ms run. (like multi_v1.0.0-200430-1) OPTIONAL

Please note that the app 'manually' downloads QC output files from the relevant tools' output folders named after the app. The app names MUST contain the module terms:
'vcfeval', 'picard', 'sentieon', 'verifybamid', 'fastqc', 'samtools', 'vcf_qc'
and adhere to the specified outdir structure:
picard/QC/data_files, verifybamid/QC/data_files, sentieon/sample_folder/data_files, other tools output all files into their folder

## What does this app do?
This app runs the East GLH fork of MultiQC to generate run wide quality control (QC) using the outputs from 'our' pipelines including:
* bcl2fastq
* VCFeval Hap.py - INDEL and SNP values are split into separate tables
* Het-hom analysis (based on vcf_qc outputs)
* Verifybamid
* Sentieon and Picard
* Samtools/flagstat
* FastQC 

## What does this app output?
The following outputs are placed in the DNAnexus project in the specified output folder:
* a HTML QC report (with the name of the runfolder)
* a folder containing the outputs in text format. (folder named after project-multiqc_data)

## How does this app work?
1. The app downloads all files within all the $project_for_multiQC/output/$ss_for_multiQC/QCapp directories of the project.
2. The app uses a modified version of MultiQC v1.9. This version differs from the official release only in the addition of a Sentieon module that parses the Sentieon-dnaseq QC files (equivalent to the Picard modules of the same name) and the happy module that shows SNP and indel precision/recall values in separate tables to allow for different thresholds to be set. The forked repo with all dependecies have been dockerised and a tarball of the docker image is in the /resources directory of the app.
3. MultiQC parses all recognised files and includes them in the report.
4. The MultiQC outputs are uploaded to DNAnexus.

## This app was made by EMEE GLH
