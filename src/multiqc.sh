#!/bin/bash
# multiqc 1.2.0

# Exit at any point if there is any error and output each line as it is executed (for debugging)
set -e -x -o pipefail

main() {

    sudo apt-get -q install parallel -y
    sudo apt-get -q install jq -y
    python3 -m pip install -qr requirements.txt

    # Download the config file
    dx download "$eggd_multiqc_config_file" -o config.yaml

    # xargs strips leading/trailing whitespace from input strings submitted by the user
    project=$(echo $project_for_multiqc | xargs) # project name
    ss=$(echo $ss_for_multiqc | xargs)           # main workflow name or absolut path to single folder

    # Make directory to pull in all QC files
    mkdir inp

    case $single_folder in
        (true)       # development
            echo "Downloading all files from the given project:/path/to/folder"
            dx download $project:/$ss/* -o ./inp/
            # substitute '\' with '-' in the single folder path
            renamed=${ss//\//-}
            ss=$renamed
            ;;
        (false)      # production
            echo "Download all QC metrics from the folders specified in the config file"
            yq '.["dx_sp"]' config.yaml > config.json
            workflowdir="$project:/output/$ss"

            if [[ ! -z ${ms_for_multiqc} ]]; then
                ms=$(echo $ms_for_multiqc | xargs)       # multi sample workflow
                python3 download_data.py $workflowdir --multi $ms
            else
                python3 download_data.py $workflowdir
            fi

            # Download Stats.json from the project
            stats=$(dx find data --brief --path ${project}: --name "Stats.json")
            if [[ ! -z $stats ]]; then
                echo "Downloading Stats.json from the given project"
                dx download $stats -o ./inp/
            fi
            ;;
    esac

    # If the option was selected to calculate additional coverage:
    case $custom_coverage in
        (true)
            mkdir calc_cov  #stores HSmetrics.tsv files to calculate custom coverage
            # Copy HSmetrics.tsv files into separate folder for custom coverage calculation
            cp inp/*hsmetrics.tsv calc_cov
            # Run the Python script, returns output into inp/
            python3 calc_custom_coverage.py calc_cov
            ;;
    esac

    # Remove 002_ from the beginning of the project name, if applicable
    if [[ "$project" == 002_* ]]; then project=${project:4}; fi
    # Remove '_clinicalgenetics' from the end of the project name, if applicable
    if [[ "$project" == *_clinicalgenetics ]]; then project=${project%_clinicalgenetics}; fi

    # Rename inp folder to a more meaningful one for downstream processing
    mv inp "$(echo $project)-$(echo $ss)"
    # Create the output folders that will be recognised by the job upon completion
    outdir=out/multiqc_data_files && mkdir -p ${outdir}
    report_outdir=out/multiqc_html_report && mkdir -p ${report_outdir}
    report_name="$(echo $project)-$(echo $ss)-multiqc"

    # Load the docker image and then run it
    docker load -i multiqc_v1.11.tar.gz
    docker run -v /home/dnanexus:/egg ewels/multiqc:v1.11 /egg/"$(echo $project)-$(echo $ss)" -c /egg/config.yaml -n /egg/${outdir}/$report_name.html

    # Move the config file to the multiqc data output folder. This was created by running multiqc
    mv config.yaml ${outdir}/$eggd_multiqc_config_file_name
    # Move the multiqc report HTML to the output directory for uploading
    mv ${outdir}/$report_name.html ${report_outdir}
    # Upload results
    dx-upload-all-outputs --parallel

}
