#!/bin/bash
# multiqc 1.2.0

# Exit at any point if there is any error and output each line as it is executed (for debugging)
set -e -x -o pipefail

main() {

    echo "Installing packages"
    sudo dpkg -i sysstat*.deb
    sudo dpkg -i parallel*.deb
    # sudo dpkg -i libonig2*.deb
    sudo dpkg -i jq*.deb
    cd packages
    pip install -q pytz-* python_dateutil-* numpy-* pandas-* jq--* yq-*
    cd ..

    echo "Downloading Docker image and config file"
    # Download the MultiQC docker image
    dx download "$multiqc_docker" -o MultiQC.tar.gz

    # Download the config file
    dx download "$multiqc_config_file" -o config.yaml

    # xargs strips leading/trailing whitespace from input strings submitted by the user
    project=$(echo $project_for_multiqc | xargs) # project name
    primary=$(echo $primary_workflow_output | xargs)  # primary workflow name or absolute path to single folder

    # Make directory to pull in all QC files
    mkdir inputs

    case $single_folder in
        (true)       # development
            echo "Downloading all files from the given project:/path/to/folder"
            dx download $project:/$primary/* -o ./inputs/
            # substitute '\' with '-' in the single folder path
            renamed=${primary//\//-}
            primary=$renamed
            ;;
        (false)      # production
            echo "Download all QC metrics from the folders specified in the config file"
            yq '.["dx_sp"]' config.yaml > config.json
            workflowdir="$project:/output/$primary"

            # Option 2: go with the Python script
            if [[ ! -z ${secondary_workflow_output} ]]; then
                secondary=$(echo $secondary_workflow_output | xargs) # eg Dias multi-sample workflow
                python3 download_data.py $workflowdir --multi $secondary
            else
                python3 download_data.py $workflowdir
            fi

            # Download Stats.json from the project
            stats=$(dx find data --brief --path ${project}: --name "Stats.json")
            if [[ ! -z $stats ]]; then
                dx download $stats -o ./inputs/
            fi
            ;;
    esac

    # If the option was selected to calculate additional coverage:
    case $calc_custom_coverage in
        (true)
            echo "Calculating coverage at custom depths"
            mkdir hsmetrics_files  #stores HSmetrics.tsv files to calculate custom coverage
            # Copy HSmetrics.tsv files into separate folder for custom coverage calculation
            cp inputs/*hsmetrics.tsv hsmetrics_files
            # Run the Python script, returns output into inputs/
            echo "$depths"
            python3 calc_custom_coverage.py hsmetrics_files "$depths"
            ;;
    esac

    # Remove 002_ from the beginning of the project name, if applicable
    if [[ "$project" == 002_* ]]; then project=${project#"002_"}; fi
    # Remove '_clinicalgenetics' from the end of the project name, if applicable
    if [[ "$project" == *_clinicalgenetics ]]; then project=${project%"_clinicalgenetics"}; fi
    # Rename inputs folder to a more meaningful one to be displayed in the report
    # Set the report name to include the project and primary workflow
    folder_name="${project}-${primary}"
    mv inputs "$folder_name"
    report_name="$folder_name-multiqc.html"

    # Create the output folders that will be recognised by the job upon completion
    report_outdir=out/multiqc_html_report && mkdir -p ${report_outdir}
    outdir=out/multiqc_data_files && mkdir -p ${outdir}

    echo "Running MultiQC on the downloaded QC metric files"
    # Load the docker image and then run it
    docker load -i MultiQC.tar.gz
    docker run -v /home/dnanexus:/egg ewels/multiqc:v1.11 /egg/"$folder_name" -c /egg/config.yaml -n /egg/${outdir}/$report_name

    echo "Uploading the config file, html report and a folder of data files"
    # Move the config file to the multiqc data output folder. This was created by running multiqc
    mv config.yaml ${outdir}/$multiqc_config_file_name
    # Move the multiqc report HTML to the output directory for uploading
    mv ${outdir}/$report_name.html ${report_outdir}
    # Upload results
    dx-upload-all-outputs --parallel
}
