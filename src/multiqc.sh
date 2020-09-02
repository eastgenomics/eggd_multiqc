#!/bin/bash
# multiqc 1.0.5

# Exit at any point if there is any error and output each line as it is executed (for debugging)
set -e -x -o pipefail

main() {
   
    # Download the config file
    dx download "$eggd_multiqc_config_file" -o eggd_multiqc_config_file

    # xargs strips leading/trailing whitespace from input strings submitted by the user
    project=$(echo $project_for_multiqc | xargs) # project name
    ss=$(echo $ss_for_multiqc | xargs)           # single sample workflow
    ms=$(echo $ms_for_multiqc | xargs)           # multi sample workflow

    # Get all the QC files (stored in output/run/app/? folder) and put into 'inp'
    # eg. 003_200415_DiasBatch:/output/dias_v1.0.0_DEV-200429-1/fastqc
    wfdir="$project:/output/$ss"
    mkdir inp   # stores files to be used as input for MultiQC
    # Download happy reports into input folder
    for h in $(dx ls ${wfdir}/"$ms" --folders); do
        if [[ $h == *vcfeval*/ ]]; then
            dx download ${wfdir}/"$ms"/"$h"/* -o ./inp/
        fi
    done
    
    # Download all other reports from the single_sample workflow output folders
    for f in $(dx ls ${wfdir} --folders); do
        # echo "Searching for reports"
        if [[ $f == *picardqc*/ ]] || [[ $f == *verifybamid*/ ]]; then
            dx download ${wfdir}/"$f"/QC/* -o ./inp/
        elif [[ $f == *sentieon*/ ]]; then
            for s in $(dx ls ${wfdir}/"$f" --folders); do
                dx download ${wfdir}/"$f"/"$s"/* -o ./inp/
            done
        elif [[ $f == *fastqc*/ ]] || [[ $f == *samtools*/ ]] || [[ $f == *vcf_qc*/ ]]; then
            dx download ${wfdir}/"$f"/* -o ./inp/
        fi
    done

    # Create the output folders that will be recognised by the job upon completion
    filename="$(echo $project)-$(echo $ss)-multiqc"
    outdir=out/multiqc_data_files && mkdir -p ${outdir}
    report_outdir=out/multiqc_html_report && mkdir -p ${report_outdir}
 
    # A modified MultiQC is installed from eastgenomics repo and run  
    # Make sure pip is up to date
    pip3 install --upgrade pip==20.1
    pip3 install --ignore-installed 'PyYAML==5.3.1'
    pip3 install -r /requirements.txt

    # Download our MultiQC fork with the Sentieon module added, and install it with pip
    git clone https://github.com/eastgenomics/MultiQC.git
    cd MultiQC
    git checkout 4846836 # This is the commit with the module added but not merged with 1.9Dev
    python3 -m pip install -e .
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
