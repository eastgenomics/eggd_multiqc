#!/bin/bash
# multiqc 2.0.0

# Exit at any point if there is any error and output each line as it is executed (for debugging)
set -e -x -o pipefail

main() {

    echo "Installing packages"
    sudo dpkg -i sysstat*.deb
    sudo dpkg -i parallel*.deb
    sudo dpkg -s jq | grep -i version

    cd packages
    pip install -q jq-* yq-*
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
    touch input_files.txt

    case $single_folder in
        (true)       # development
            echo "Downloading all files from the given project:/path/to/folder"
            dx ls --brief $project:/$primary/ > input_files.txt
            dx download $project:/$primary/* -o ./inputs/
            # substitute '\' with '-' in the single folder path
            renamed=${primary//\//-}
            primary=$renamed
            ;;
        (false)      # production
            echo "Download all QC metrics from the folders specified in the config file"
            yq '.["dx_sp"]' config.yaml > config.json

            # Check that an /output/ folder exists in the root of the project
            if [[ $(dx find data --path "$primary") ]]; then
                # found data in specified dir => use it
                workflowdir="$project:/$primary"
            elif [[ $(dx find data --path "/output/${primary}") ]]; then
                # dir specified without output prefix
                workflowdir="$project:/output/${primary}"
            else
                dx-jobutil-report-error "Given primary output directory does not contain data"
            fi

            # get all file patterns of files to download from primary workflow output folder,
            # then find and download from project in given folder
            for pattern in $(jq -r '.["primary"] | flatten | join(" ")' config.json); do
                dx find data --brief --path "$workflowdir" --name "$pattern"  >> input_files.txt
                dx find data --brief --path "$workflowdir" --name "$pattern" | \
                xargs -P4 -n1 -I{} dx download {} -o ./inputs/
            done

            if [[ ! -z ${secondary_workflow_output} ]]; then
                secondary=$(echo $secondary_workflow_output | xargs) # eg Dias multi-sample workflow
                
                # get all file patterns of files to download from secondary workflow output folder,
                # then find and download from project in given folder
                for pattern in $(jq -r '.["secondary"] | flatten | join(" ")' config.json); do
                    dx find data --brief --path "$workflowdir"/"$secondary" --name "$pattern"  >> input_files.txt
                    dx find data --brief --path "$workflowdir"/"$secondary" --name "$pattern" | \
                    xargs -P4 -n1 -I{} dx download {} -o ./inputs/
                done
            fi

            # Download Stats.json from the project
            stats=$(dx find data --brief --path ${project}: --name "Stats.json")
            if [[ ! -z $stats ]]; then
                echo $stats >> input_files.txt
                dx download $stats -o ./inputs/
            fi
            ;;
    esac

    # If the option was selected to calculate additional coverage:
    case $calc_custom_coverage in
        (true)
            echo "Installing required Python packages"
            cd packages
            pip install -q pytz-* python_dateutil-* numpy-* pandas-*
            cd ..

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
    docker run -v /home/dnanexus:/egg $MultiQC_image /egg/"$folder_name" -c /egg/config.yaml -n /egg/${outdir}/$report_name

    echo "Uploading the config file, html report and a folder of data files"
    # Move the config file to the multiqc data output folder. This was created by running multiqc
    mv config.yaml ${outdir}/$multiqc_config_file_name
    # Move the multiqc report HTML to the output directory for uploading
    mv ${outdir}/$report_name ${report_outdir}
    # Upload the input_files.txt to keep an audit trail
    mv input_files.txt ${outdir}/
    # Upload results
    dx-upload-all-outputs --parallel
}
