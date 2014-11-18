#!/bin/bash
# rampage-align-pe 1.0.0

main() {
    # Now in resources/usr/bin
    #echo "* Download and install STAR..."
    #git clone https://github.com/alexdobin/STAR
    #(cd STAR; git checkout tags/STAR_2.4.0d)
    #(cd STAR; make)
    #wget https://github.com/samtools/samtools/archive/0.1.19.tar.gz

    echo "*****"
    echo "* Running: rampage-align-pe.sh [v0.0.1]"
    echo "* STAR version: "`STAR --version | awk '{print $1}' | cut -d _ -f 2-`
    #echo "* samtools version: "`samtools 2>&1 | grep Version | awk '{print $2}'`
    echo "*****"

    echo "* Value of reads_1: '$reads_1'"
    echo "* Value of reads_2: '$reads_2'"
    echo "* Value of star_index: '$star_index'"
    echo "* Value of library_id: '$library_id'"
    echo "* Number of threads (default 8): '$nthreads'"

    echo "* Download files..."
    reads1_fn=`dx describe "$reads_1" --name`
    reads1_fn=${reads1_fn%.fastq.gz}
    reads1_fn=${reads1_fn%.fq.gz}
    dx download "$reads_1" -o "$reads1_fn".fastq.gz
    reads2_fn=`dx describe "$reads_2" --name`
    reads2_fn=${reads2_fn%.fastq.gz}
    reads2_fn=${reads2_fn%.fq.gz}
    dx download "$reads_2" -o "$reads2_fn".fastq.gz
    echo "* Read files: '${reads1_fn}.fastq.gz' '${reads2_fn}.fastq.gz'"

    dx download "$star_index" -o star_index.tgz
    tar zxvf star_index.tgz
    # unzips into "out/"

    # Fill in your application code here.

    echo "* Set up headers..."
    libraryComment="@CO\tLIBID:${library_id}"
    echo -e ${libraryComment} > COfile.txt
    cat out/*_bamCommentLines.txt >> COfile.txt
    echo `cat COfile.txt`

    echo "* Map reads..."
    STAR --genomeDir out --readFilesIn ${reads1_fn}.fastq.gz ${reads2_fn}.fastq.gz \
        --readFilesCommand zcat --runThreadN ${nthreads} --genomeLoad NoSharedMemory \
        --outFilterMultimapNmax 20 --alignSJoverhangMin 8 --alignSJDBoverhangMin 1     \
        --outFilterMismatchNmax 999 --outFilterMismatchNoverReadLmax 0.04                \
        --alignIntronMin 20 --alignIntronMax 1000000 --alignMatesGapMax 1000000            \
        --outSAMheaderCommentFile COfile.txt --outSAMheaderHD @HD VN:1.4 SO:coordinate       \
        --outSAMunmapped Within --outFilterType BySJout --outSAMattributes NH HI AS NM MD      \
        --outFilterScoreMinOverLread 0.85 --outFilterIntronMotifs RemoveNoncanonicalUnannotated  \
        --clip5pNbases 6 15 --seedSearchStartLmax 30 --limitBAMsortRAM 30000000000 \
        --outSAMtype BAM SortedByCoordinate

    #echo "* Marking PCR duplicates..."
    STAR --inputBAMfile Aligned.sortedByCoord.out.bam --bamRemoveDuplicatesType UniqueIdentical \
        --runMode inputAlignmentsFromBAM --bamRemoveDuplicatesMate2basesN 15 \
        --limitBAMsortRAM 30000000000 --outFileNamePrefix markdup.

    echo "* Upload results..."
    #echo "* Index genome bam..."
    # Note: No longer making unused index
    mv markdup.Processed.out.bam ${reads1_fn}-${reads2_fn}_star_marked.bam
    #samtools index ${reads1_fn}-${reads2_fn}_star_marked.bam
    #mv Aligned.toTranscriptome.out.bam ${reads1_fn}-${reads2_fn}_star_anno.bam
    mv Log.final.out ${reads1_fn}-${reads2_fn}_star_Log.final.out

    star_log=$(dx upload ${reads1_fn}-${reads2_fn}_star_Log.final.out --brief)
    marked_bam=$(dx upload ${reads1_fn}-${reads2_fn}_star_marked.bam --brief)

    dx-jobutil-add-output star_log "$star_log" --class=file
    dx-jobutil-add-output genome_bam "$marked_bam" --class=file
    echo "* Finished."
}