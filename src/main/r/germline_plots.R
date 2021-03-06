library(ggplot2)
library(scales)
library(RColorBrewer)
library(GenomicRanges)
library(rtracklayer)
library(data.table)
library(stringr)
source("libgridss.R")



##################
# Set up data frame
##################
vcf <- gridss.removeUnpartnerededBreakend(vcf)
df <- gridss.truthdetails.processvcf.vcftodf(vcf)

###############
# Socrates variant calling concordance
###############
socBedMate <- str_match(socBed$name, "bp[[:digit:]]+_to_bp[[:digit:]]+_([[:alnum:]]+):([[:digit:]]+)-([[:digit:]]+)")
socBedMate <- GRanges(seqnames=socBedMate[,2], ranges=IRanges(start=as.numeric(socBedMate[,3]), end=as.numeric(socBedMate[,4]), names=socBedMate[,1]), strand="*")
socBed <- gridss.annotateBreakpointHits(socBed, socBedMate, vcf, maxgap=16, ignore.strand=TRUE) # TODO: consistent strand meaning

ggplot(as.data.frame(mcols(socBed)), aes(x=score, fill=called)) +
  geom_histogram() +
  scale_x_log10() + 
  labs(title="Concordance with existing Socrates calls")
ggsave("778_soc_histogram.png", width=10, height=7.5)

ggplot(as.data.frame(mcols(socBed)), aes(x=score, y=qual, color=called)) +
  geom_point() +
  scale_x_log10() + scale_y_log10() + 
  labs(title="Concordance with existing Socrates calls")
ggsave("778_soc_concordance.png", width=10, height=7.5)


###############
# Background filter model
###############
# what's a good fit?
for (windowSize in c(1, 10, 100, 100, 1000)) {
  dfWindow <- rbind(dfWindow, data.frame(QUAL=rowData(vcf)$QUAL, count=countQueryHits(findOverlaps(rowData(vcf), rowData(vcf), maxgap=windowSize)), windowSize=windowSize))
}
dfWindow$countBin <- cut(dfWindow$count, c(0, 1, 2, 4, 8, 16, 32, 64, 128, 256, Inf))
ggplot(dfWindow, aes(x=count, y=QUAL, color=factor(windowSize))) + geom_point() + scale_y_log10()
ggplot(dfWindow, aes(x=QUAL)) + 
  geom_density() + 
  facet_grid(countBin ~ windowSize) +
  scale_x_log10() + 
  labs(title="Breakpoint call clustering by window size", color="Number of calls in window")


###############
# Microhomology size distribution
###############
ggplot(df, aes(x=HOMLEN, color=confidence)) + geom_density(adjust=2) + scale_x_continuous(limits=c(0, 25))


###############
# Evidence distributions
###############
ggplot(evidence[evidence$class=="DiscordantReadPair",], aes(x=breakpointQual)) + geom_histogram() + labs(title="Discordant read pair quality score distribution")
ggplot(evidence[evidence$class=="RealignedSoftClipEvidence",], aes(x=breakpointQual)) + geom_histogram() + labs(title="Split read quality score distribution")
ggplot(evidence[evidence$class=="RealignedSAMRecordAssemblyEvidence",], aes(x=breakpointQual, color=class)) + geom_histogram() + scale_x_log10() + labs(title="Assembly quality score distribution")
aggregate(evidence$breakpointQual, list(evidence$class), mean)
aggregate(evidence$breakendQual, list(evidence$class), mean)


###############
# Exploratory plots
###############
ggplot(df[df$RP==0&df$SC==0&df$RSC==0,], aes(x=QUAL)) + geom_histogram()

###############
# Exploratory plots
###############

ggplot(df[df$QUAL>100&df$RP>0,], aes(x=RP, y=QUAL-ASQ-RASQ-SCQ-RSCQ, color=factor(pmin(AS, 1)+pmin(RAS, 1)))) + geom_point() +
  scale_x_log10() + scale_y_log10() +
  stat_smooth(method = "lm") + 
  labs(title="RP")

# Contribution of local breakend evidence
ggplot(df, aes(x=QUAL, y=BQ, color=, size=BAS+1)) + geom_point() + scale_x_log10() + scale_y_log10() + facet_grid(cgrmate ~ cgr) +
  labs(title="Breakpoint and breakend quality score distributions according to breakend CGR location")

# Assembly rate by evidence QUAL
ggplot(df, aes(x=SC+RSC+RP+BSC+BRP, color=factor(pmin(AS, 1)+pmin(RAS, 1)))) + geom_density() + scale_x_log10(limits=c(25, 10000)) +
  labs(title="Assembly rate by evidence quality")
ggplot(df, aes(x=SC+RSC+RP+BSC+BRP, fill=factor(pmin(AS, 1)+pmin(RAS, 1)))) + geom_bar(position = 'fill') + scale_x_log10(limits=c(25, 10000))

ggplot(df, aes(x=QUAL-ASQ-RASQ, fill=hasAS)) +
  geom_bar(position='fill') +
  scale_x_log10(limits=c(25, 10000), expand=c(0, 0)) +
  scale_y_continuous(labels=percent, expand=c(0, 0)) +
  labs(title="Assembly rate", x="Quality of read pair and split read evidence", y="")

ggplot(df, aes(x=SC+RSC+RP+BSC+BRP, fill=hasAS)) + geom_bar(position='fill') + scale_x_log10(limits=c(3, 500)) + scale_y_continuous(labels=percent)


# Effect of unique read madfing
# TODO: why to points exist where QUAL > CQ ? this should not be possible
ggplot(df, aes(x=QUAL, y=CQ, color=factor(pmin(AS, 1)+pmin(RAS, 1)))) + geom_point() + scale_x_log10() + scale_y_log10()
# histogram of 
ggplot(df, aes(x=QUAL/CQ)) + geom_histogram()# + scale_y_log10()
head(df[df$QUAL > df$CQ & df$CQ > 100,])

# evidence counts
ggplot(df, aes(x=RP, y=SC+RSC, color=factor(pmin(AS, 1)+pmin(RAS, 1)))) + facet_grid(cgrmate ~ cgr) + geom_point() + scale_x_log10() + scale_y_log10() + geom_jitter(position = position_jitter(width = 1, height=1))

table(data.frame(a=df$cgr, b=df$cgrmate)) /2 

# qual dist
# AS remote can be removed due to symmetry
ggplot(df[df$hasAS != "AS remote" & !(df$hasSC == "SC remote" & df$hasAS != "AS local"), ],
    aes(x=QUAL)) +
  facet_grid(hasRP + hasAS ~ hasSC) + 
  geom_histogram() + scale_x_log10() + scale_y_log10() +
  theme_bw() + labs(title="Breakpoint quality distribution by evidence type")
ggplot(df, aes(x=QUAL, y=BQ)) + facet_grid(hasRP + hasSC ~ hasAS) + geom_point() + scale_x_log10() + scale_y_log10()

# local anchor length shouldn't mean much
ggplot(df, aes(x=A_BLRM, y=A_BLLM)) + geom_point()

# should have a linear relationship
ggplot(df, aes(x=RC+1, y=PC+1, color=log(QUAL))) + geom_smooth() + geom_jitter() + geom_point() + scale_y_log10() + scale_x_log10() + scale_colour_gradientn(colours=c("red", "blue"))

ggplot(df, aes(x=SC + RSC, y=REF, color=REFPAIR)) + geom_point()

# assembly length vs breakpoint quality
ggplot(df, aes(x=A_BLRM, y=QUAL)) + geom_point()

# coverage
ggplot(df, aes(x=REF)) + geom_histogram() + scale_x_log10()
ggplot(df, aes(x=REFPAIR)) + geom_histogram() + scale_x_log10()
ggplot(df, aes(x=SC)) + geom_histogram() + scale_x_log10()
ggplot(df, aes(x=RSC)) + geom_histogram() + scale_x_log10()
ggplot(df, aes(x=AS)) + geom_histogram() + scale_x_log10()
ggplot(df, aes(x=RAS)) + geom_histogram() + scale_x_log10()
ggplot(df, aes(x=RP)) + geom_histogram() + scale_x_log10()


# distribution of variant evidence contribution
ggplot(df, aes(x=SC, y=REF, color=1)) + geom_point() + scale_y_log10() + scale_x_log10() + scale_colour_gradientn(colours=rainbow(4)) 
# normal coverage
ggplot(df, aes(x=RCNormal + SCECNormal)) + geom_histogram()

# Effect of local breakend evidence & unique evidence assignment
ggplot(df, aes(x=QUAL, y=CQUAL)) + geom_point() + scale_x_log10() + scale_y_log10()




# QUAL distribution by breakpoint evidence
ggplot(df, aes(x=RP + SC + RSC)) + geom_histogram()

# total evidence distribution
ggplot(df, aes(x=log10(RPEC+A_RP+1), y=log10(SCEC+A_SC+1), color=factor(A_EC))) +  geom_point() + ggtitle("All evidence") + scale_x_continuous(limits=c(0, 3.5)) + scale_y_continuous(limits=c(0, 3.5))
ggsave("evidence_distribution_all.png")
# non-assembly evidence distribution
ggplot(df, aes(x=log10(RPEC+1), y=log10(SCEC+1), color=factor(A_EC))) + geom_point() + ggtitle("Non-assembly evidence") + scale_x_continuous(limits=c(0, 3.5)) + scale_y_continuous(limits=c(0, 3.5))
ggsave("evidence_distribution_notassembled.png")
# distribution of evidence not in assembly
ggplot(df, aes(x=log10(A_RP+1), y=log10(A_SC+1), color=factor(A_EC))) + geom_point() + ggtitle("Assembly evidence") + scale_x_continuous(limits=c(0, 3.5)) + scale_y_continuous(limits=c(0, 3.5))
ggsave("evidence_distribution_assembled.png")


# how many assemblies where we have no madfed evidence?
nrow(df[df$SCRM==0 & df$RPRM==0 & df$A_RM==0,]) # = number of calls in which *ALL* the breakpoint evidence has been removed -> no sudfort for this variant yet we're calling them
# created breakpoint from assembly
ggplot(df[df$SCRM==0 & df$RPRM==0,], aes(x=A_MQT)) + geom_histogram()
# great assemblies in both directions
head(df[df$SCRM==0 & df$RPRM==0 & df$A_MQT>80,])



###############
# Chromothripsis feature finding
###############
vcf <- vcf[fixed(vcf)$QUAL > 500,]

hits <- findOverlaps(rowData(vcf), rowData(vcf))
hits <- hits[queryHits(hits) != subjectHits(hits),]
hitRows <- rowData(vcf[unique(queryHits(hits)),])
hitLocations <- unique(paste0(seqnames(hitRows), ":", start(ranges(hitRows))))








