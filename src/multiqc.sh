#!/bin/bash

# Exit at any point if there is any error and output each line as it is executed (for debugging)
set -e -x -o pipefail
# set frequency of instance usage in logs to 30 seconds
kill $(ps aux | grep pcp-dstat | head -n1 | awk '{print $2}')
/usr/bin/dx-dstat 30

main() {
    echo "Downloading Docker image and config file"
    dx download "$multiqc_docker" -o MultiQC.tar.gz
    dx download "$multiqc_config_file" -o config.yaml

    # xargs strips leading/trailing whitespace from input strings submitted by the user
    project=$(echo $project_for_multiqc | xargs) # project name
    primary=$(echo $primary_workflow_output | xargs)  # primary workflow name or absolute path to single folder

    # Make directory to pull in all QC files
    mkdir inputs
    touch input_files.txt

    echo "Download all QC metrics from the folders specified in the config file"
    if [[ $(dx find data --path "${project}:/$primary") ]]; then
        # found data in specified dir => use it
        workflowdir="$project:/$primary"
    elif [[ $(dx find data --path "${project}:/output/${primary}") ]]; then
        # dir specified without output prefix
        workflowdir="$project:/output/${primary}"
    else
        dx-jobutil-report-error "Given primary output directory does not contain data"
    fi
    # get all file patterns of files to download from primary workflow output folder,
    # then find and download from project in given folder
    for pattern in $(~/yq_4.45.1 -r '.["dx_sp"].["primary"].[] | flatten | join(" ")' config.yaml); do
        dx find data --brief --path "$workflowdir" --name "$pattern"  >> input_files.txt
    done

    cat input_files.txt | xargs -P$(nproc --all) -n1 -I{} dx download -f {} -o ./inputs/

    # Download all /demultiplex_multiqc_files
    echo "Looking for files in /demultiplex_multiqc_files"
    demultiplex_multiqc_files_directory="${project}:/demultiplex_multiqc_files"

    # Check if the directory exists and contains any files
    if dx find data --path "$demultiplex_multiqc_files_directory" --brief; then
        echo "Downloading files from $demultiplex_multiqc_files_directory"
        # Fetch and download InterOp files in parallel
        dx find data --brief --path "$demultiplex_multiqc_files_directory" \
          | tee -a input_files.txt \
          | xargs -P$(nproc --all) -n1 -I{} dx download -f {} -o ./inputs/
    else
        echo "No files found in /demultiplex_multiqc_files"
    fi

    # If the option was selected to calculate additional coverage:
    case $calc_custom_coverage in
        (true)
            echo "Installing required Python packages"
            sudo -H python3 -m pip install --no-index --no-deps packages/*

            echo "Calculating coverage at custom depths"
            mkdir hsmetrics_files  #stores HSmetrics.tsv files to calculate custom coverage
            # Copy HSmetrics.tsv files into separate folder for custom coverage calculation
            cp inputs/*hsmetrics.tsv hsmetrics_files
            # Run the Python script, returns output into inputs/
            echo "$depths"
            python3 calc_custom_coverage.py hsmetrics_files "$depths"
            ;;
    esac

    # Remove 002_ from the beginning of the project name
    project=${project#"002_"}
    # Remove '_clinicalgenetics' from the end of the project name
    project=${project%"_clinicalgenetics"}
    # Rename inputs folder to a more meaningful one to be displayed in the report
    # Set the report name to include the project and primary workflow
    folder_name="${project}-${primary##*/}"
    mv inputs "$folder_name"
    report_name="$folder_name-multiqc.html"

    # Create the output folders that will be recognised by the job upon completion
    report_outdir=out/multiqc_html_report && mkdir -p ${report_outdir}
    outdir=out/multiqc_data_files && mkdir -p ${outdir}

    echo "Running MultiQC on the downloaded QC metric files"
    # Load the docker image and then run it
    docker load -i MultiQC.tar.gz
    MultiQC_image=$(docker images --format="{{.Repository}} {{.ID}}" | grep multiqc | cut -d' ' -f2)
    docker run -v /home/dnanexus:/egg -w /egg $MultiQC_image multiqc "$folder_name" -c config.yaml

    echo "Uploading the config file, html report and a folder of data files"
    mv multiqc_data ${outdir}/
    # Move the config file to the multiqc data output folder. This was created by running multiqc
    mv config.yaml ${outdir}/$multiqc_config_file_name
    # Move the multiqc report HTML to the output directory for uploading
    mv multiqc_report.html ${report_outdir}/$report_name
    # Upload the input_files.txt to keep an audit trail
    mv input_files.txt ${outdir}/
    # Upload results
    dx-upload-all-outputs --parallel
}
