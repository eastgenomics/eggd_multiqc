#!/bin/bash
# multiqc 1.0.3

# Exit at any point if there is any error and output each line as it is executed (for debugging)
set -e -x -o pipefail

main() {

    # Download the config file
    dx download "$eggd_multiqc_config_file" -o eggd_multiqc_config_file

    # Get all the QC files (stored in output/run/app/? folder) and put into 'inp'
    # eg. 003_200415_DiasBatch:/output/dias_v1.0.0_DEV-200429-1/fastqc
    wfdir="$project_for_multiqc:/output/$ss_for_multiqc"
    mkdir inp
    mkdir happy
    # Download happy reports into happy folder
    for h in $(dx ls ${wfdir}/"$ms_for_multiqc" --folders); do
        if [[ $h == *vcfeval*/ ]]; then
            dx download ${wfdir}/"$ms_for_multiqc"/"$h"/* -o ./happy/
        fi
    done
    
    # Download all other reports from the single_sample workflow output folders
    for f in $(dx ls ${wfdir} --folders); do
        # echo "Searching for reports"
        if [[ $f == *picardqc*/ ]] || [[ $f == verifybamid*/ ]]; then
            dx download ${wfdir}/"$f"/QC/* -o ./inp/
        elif [[ $f == sentieon*/ ]]; then
            for s in $(dx ls ${wfdir}/"$f" --folders); do
                dx download ${wfdir}/"$f"/"$s"/* -o ./inp/
            done
        elif [[ $f == fastqc/ ]] || [[ $f == samtools*/ ]] || [[ $f == *vcf_qc*/ ]]; then
            dx download ${wfdir}/"$f"/* -o ./inp/
        fi
    done

    # Split happy output summary.csv into snp.csv and indel.csv
    if find './happy/' -type f -name *summary.csv; then
        INPUT=$(find './happy/' -type f -name *summary.csv)
        OLDIFS=$IFS
        IFS=','
        touch inp/snp.csv
        touch inp/indel.csv
        [ ! -f $INPUT ] && { echo "$INPUT file not found"; exit 99; }
        while read -r type filter a b c d e f g recall precision rest
        do
                if [ "$type" == "INDEL" ]; then
                echo "${type}_${filter},${recall},${precision}" >> inp/indel.csv
                elif [ "$type" == "SNP" ]; then
                echo "${type}_${filter},${recall},${precision}" >> inp/snp.csv
                else
                echo "${type}_${filter},${recall},${precision}" >> inp/indel.csv
                echo "${type}_${filter},${recall},${precision}" >> inp/snp.csv
                fi
        done < $INPUT
        echo "Happy output successfully split"
    fi

    # Create the output folders that will be recognised by the job upon completion
    filename="$(echo $project_for_multiqc)-$(echo $ss_for_multiqc)-multiqc"
    outdir=out/multiqc_data_files && mkdir -p ${outdir}
    report_outdir=out/multiqc_html_report && mkdir -p ${report_outdir}
 
    # A modified MultiQC is installed from eastgenomics repo and run  
    # Make sure pip is up to date
    pip install --upgrade pip==20.1

    # Download our MultiQC fork with the Sentieon module added, and install it with pip
    git clone https://github.com/eastgenomics/MultiQC.git
    cd MultiQC
    git checkout 6c66676  # This is the commit with the module added but not merged with 1.9Dev
    pip install -e .
    cd ..
    # Add the install location to PATH
    export PATH=$PATH:/home/dnanexus/.local/bin
    # Show MultiQC version (should not be the Dev version)
    multiqc --version

    # Run multiQC
    multiqc ./inp/ -n ./${outdir}/$filename.html -c /home/dnanexus/eggd_multiqc_config_file

    # Move the config file to the multiqc data output folder. This was created by running multiqc
    mv eggd_multiqc_config_file ${outdir}/$filename_data/
    # Move the multiqc report HTML to the output directory for uploading
    mv ${outdir}/$filename.html ${report_outdir}

    # Upload results
    dx-upload-all-outputs

}
