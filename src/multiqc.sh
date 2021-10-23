#!/bin/bash
# multiqc 1.2.0

# Exit at any point if there is any error and output each line as it is executed (for debugging)
set -e -x -o pipefail

main() {

    sudo apt-get install parallel -y
    # Download the config file
    dx download "$eggd_multiqc_config_file" -o eggd_multiqc_config_file

    # xargs strips leading/trailing whitespace from input strings submitted by the user
    export project=$(echo $project_for_multiqc | xargs) # project name
    ss=$(echo $ss_for_multiqc | xargs)           # main workflow name or absolut path to single folder

    # Make directory to pull in all QC files
    mkdir inp   # stores files to be used as input for MultiQC

    # Get all the QC files (stored in a single folder project:/single/*
                             # OR in project:/output/single/app folders
                             #   and project:/output/single/multi/happy
    # and download into 'inp'

    case $single_folder in
        (true)       # development
            echo "Downloading all files from the given project:/path/to/folder"
            dx download $project:/$ss/* -o ./inp/
            # substitute '\' with '-' in the single folder path
            renamed=${ss//\//-}
            ss=$renamed
            ;;
        (false)      # production
            echo "Downloading all files from project:/output/workflow/apps"
            workflowdir="$project:/output/$ss"
            # Download Stats.json from the project
            stats=$(dx find data --brief --path ${project}: --name "Stats.json")
            if [[ ! -z $stats ]]; then
                echo "Downloading Stats.json from the given project"
                dx download $stats -o ./inp/
            fi
            # Download all qc metrics from the main or single_sample workflow output folders
            for folder in $(dx ls ${workflowdir} --folders); do
                if [[ $folder == *fastqc*/ ]] || [[ $folder == *samtools*/ ]] || [[ $folder == *vcf_qc*/ ]]; then
                    dx download ${workflowdir}/"$folder"/* -o ./inp/
                elif [[ $folder == *picard*/ ]] || [[ $folder == *verifybamid*/ ]]; then
                    dx download ${workflowdir}/"$folder"/QC/* -o ./inp/
                elif [[ $folder == *sentieon*/ ]]; then
                    dx ls ${workflowdir}/"$folder" --folders --full | parallel -I% 'dx download $project:%/* -o ./inp/'
                fi
            done
            # Download all qc metrics from the multi_sample workflow, if provided
            if [[ ! -z ${ms_for_multiqc} ]]; then
                ms=$(echo $ms_for_multiqc | xargs)       # multi sample workflow
                for folder in $(dx ls ${workflowdir}/"$ms" --folders); do
                    if [[ $folder == *vcfeval*/ ]]; then
                        echo "Downloading happy files from project:/output/sinlge/multi/happy"
                        dx download ${workflowdir}/"$ms"/"$folder"/* -o ./inp/
                    elif [[ $folder == *relate2multiqc*/ ]]; then
                        echo "Downloading somalier files from project:/output/sinlge/multi/relate2multiqc"
                        dx download ${workflowdir}/"$ms"/"$folder"/* -o ./inp/
                    fi
                done
            fi
            ;;
    esac

    # If the option was selected to calculate additional coverage:
    case $custom_coverage in
        (true)
            mkdir calc_cov  #stores HSmetrics.tsv files to calculate custom coverage
            # Copy HSmetrics.tsv files into separate folder for custom coverage calculation
            cp inp/*hsmetrics.tsv calc_cov
            
            # Add code that runs the Python script, returns the output file into inp/
            pip install 'pandas==0.24.2'  # control which version of pandas is used
            python3 calc_custom_coverage.py calc_cov
            ;;
    esac

    # Remove 002_ from the beginning of the project name, if applicable
    if [[ "$project" == 002_* ]]; then
        project=${project:4}
    fi
    # Remove '_clinicalgenetics' from the end of the project name, if applicable
    if [[ "$project" == *_clinicalgenetics ]]; then
        project=${project%_clinicalgenetics}
    fi

    # Rename inp folder to a more meaningful one for downstream processing
    mv inp "$(echo $project)-$(echo $ss)"
    # Create the output folders that will be recognised by the job upon completion
    report_name="$(echo $project)-$(echo $ss)-multiqc"
    outdir=out/multiqc_data_files && mkdir -p ${outdir}
    report_outdir=out/multiqc_html_report && mkdir -p ${report_outdir}

    # Load the docker image and then run it
    docker load -i multiqc_v1.11.tar.gz
    docker run -v /home/dnanexus:/egg ewels/multiqc:v1.11 /egg/"$(echo $project)-$(echo $ss)" -c /egg/eggd_multiqc_config_file -n /egg/${outdir}/$report_name.html

    # Move the config file to the multiqc data output folder. This was created by running multiqc
    mv eggd_multiqc_config_file ${outdir}/$report_data/
    # Move the multiqc report HTML to the output directory for uploading
    mv ${outdir}/$report_name.html ${report_outdir}

    # Upload results
    dx-upload-all-outputs --parallel

}
