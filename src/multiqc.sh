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

    # Make directory to pull in all QC files
    mkdir inp   # stores files to be used as input for MultiQC

    # Download stats.json from the project
    stats=$(dx find data --brief --path ${project}: --name "Stats.json")
    if [[ ! -z $stats ]]; then
        dx download $stats -o ./inp/
    fi

    # Get all the QC files (stored in project:/output/single/app/? folders
                             #    and project:/output/single/multi/happy

    if [[ ! -z ${ms_for_multiqc} ]]; then
        echo "Has single and multi_sample workflow provided"

        ms=$(echo $ms_for_multiqc | xargs)       # multi sample workflow

        # Get all the QC files (stored in output/run/app/? folder) and put into 'inp'
        # eg. 003_200415_DiasBatch:/output/dias_v1.0.0_DEV-200429-1/fastqc
        wfdir="$project:/output/$ss"
        # Download happy reports from the multi_sample workflow
        for h in $(dx ls ${wfdir}/"$ms" --folders); do
            if [[ $h == *vcfeval*/ ]]; then
                dx download ${wfdir}/"$ms"/"$h"/* -o ./inp/
            fi
        done

        # Download all reports from the single_sample workflow output folders
        for f in $(dx ls ${wfdir} --folders); do
            # echo "Searching for reports"
            if [[ $f == *picard*/ ]] || [[ $f == *verifybamid*/ ]]; then
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
