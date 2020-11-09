#!/bin/bash
# multiqc 1.1.1

# Exit at any point if there is any error and output each line as it is executed (for debugging)
set -e -x -o pipefail

main() {

    # Download the config file
    dx download "$eggd_multiqc_config_file" -o eggd_multiqc_config_file

    # xargs strips leading/trailing whitespace from input strings submitted by the user
    project=$(echo $project_for_multiqc | xargs) # project name
    ss=$(echo $ss_for_multiqc | xargs)           # single sample workflow or single folder name/path
    coverage=$(echo $custom_coverage)            # target bases coverage value (int)

    # Make directory to pull in all QC files
    mkdir inp   # stores files to be used as input for MultiQC
    mkdir calc_cov  #stores HSmetrics.tsv files to calculate custom coverage

    # Download stats.json either from the project folder directly or from the run1 folder
    # dx download "$project:/run1/Stats.json" -o ./inp/
    sp=$(dx find data --brief --path ${project}: --name "Stats.json")
    if [[ ! -z $sp ]]; then
        dx download $sp -o ./inp/
    fi

    # Get all the QC files (stored in project:/output/single/app/? folders
                        #         and project:/output/single/multi/happy
                        #    OR project:/folder) and put into 'inp'
    if [[ ! -z ${ms_for_multiqc} ]]; then # could also use -n instead of ! -z
        echo "Has single and multi-sample workflow provided"
        ms=$(echo $ms_for_multiqc | xargs)       # multi sample workflow
        wfdir="$project:/output/$ss"

        # Download happy reports from the multi_sample workflow
        for h in $(dx ls ${wfdir}/"$ms" --folders); do
            if [[ $h == *vcfeval*/ ]]; then
                dx download ${wfdir}/"$ms"/"$h"/* -o ./inp/
            fi
        done
        # Download all reports from the single_sample workflow output folders
        for f in $(dx ls ${wfdir} --folders); do
            if [[ $f == *picard*/ ]]; then
                dx download ${wfdir}/"$f"/QC/* -o ./inp/
                # Download HSmetrics.tsv files into separate folder for custom coverage calculation
                dx download ${wfdir}/"$f"/QC/"*hsmetrics.tsv" -o ./calc_cov/
            elif [[ $f == *verifybamid*/ ]]; then
                dx download ${wfdir}/"$f"/QC/* -o ./inp/
            elif [[ $f == *sentieon*/ ]]; then
                for s in $(dx ls ${wfdir}/"$f" --folders); do
                    dx download ${wfdir}/"$f"/"$s"/* -o ./inp/
                done
            elif [[ $f == *fastqc*/ ]] || [[ $f == *samtools*/ ]] || [[ $f == *vcf_qc*/ ]]; then
                dx download ${wfdir}/"$f"/* -o ./inp/
            fi
        done
    else
        echo "No ms given, assuming it is a single folder for MultiQC"
        dx download $project:/$ss/* -o ./inp/
        dx download $project:/$ss/"*hsmetrics.tsv" -o ./calc_cov/
        ss=${ss//\//-}
    fi

    # Remove 002_ from the beginning of the project name, if applicable
    if [[ "$project" == 002_* ]]; then
        project=${project:4}
    fi
    # Remove '_clinicalgenetics' from the end of the project name, if applicable
    if [[ "$project" == *_clinicalgenetics ]]; then
        project=${project%_clinicalgenetics}
        # project=$p
    fi

    # Add code that runs the Python script with the coverage value and returns the output file into inp/
    pip install pandas  # should control which version of pandas is used
    python3 calc_custom_coverage.py calc_cov $coverage

    # Rename inp folder to a more meaningful one for downstream processing
    mv inp "$(echo $project)-$(echo $ss)"

    # Create the output folders that will be recognised by the job upon completion
    report_name="$(echo $project)-$(echo $ss)-multiqc"
    outdir=out/multiqc_data_files && mkdir -p ${outdir}
    report_outdir=out/multiqc_html_report && mkdir -p ${report_outdir}

    # Load the docker image and then run it
    docker load -i multiqc_egg.tar.gz
    docker run -v /home/dnanexus:/egg sophie22/multiqc_egg:v1.0.0 /egg/"$(echo $project)-$(echo $ss)" -n /egg/${outdir}/$report_name.html -c /egg/eggd_multiqc_config_file

    # Move the config file to the multiqc data output folder. This was created by running multiqc
    mv eggd_multiqc_config_file ${outdir}/$report_data/
    # Move the multiqc report HTML to the output directory for uploading
    mv ${outdir}/$report_name.html ${report_outdir}

    # Upload results
    dx-upload-all-outputs

}
