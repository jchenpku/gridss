package au.edu.wehi.idsv;

import htsjdk.samtools.QueryInterval;
import htsjdk.samtools.util.CloseableIterator;

import java.util.ArrayList;
import java.util.List;

public class AggregateEvidenceSource extends EvidenceSource implements Iterable<DirectedEvidence> {
	private final SAMEvidenceSource.EvidenceSortOrder eso;
	private List<SAMEvidenceSource> all;
	public AggregateEvidenceSource(ProcessingContext processContext, List<SAMEvidenceSource> reads, AssemblyEvidenceSource assemblies, SAMEvidenceSource.EvidenceSortOrder eso) {
		super(processContext, null, null);
		this.all = new ArrayList<>(reads);
		this.eso = eso;
		if (assemblies != null) {
			this.all.add(assemblies);
		}
	}
	@Override
	public CloseableIterator<DirectedEvidence> iterator() {
		return SAMEvidenceSource.mergedIterator(all, true, eso);
	}
	public CloseableIterator<DirectedEvidence> iterator(QueryInterval[] intervals) {
		return SAMEvidenceSource.mergedIterator(all, intervals, eso);
	}
	@Override
	public int getMaxConcordantFragmentSize() {
		return all.stream().mapToInt(source -> source.getMaxConcordantFragmentSize()).max().getAsInt();
	}
	@Override
	public int getMinConcordantFragmentSize() {
		return all.stream().mapToInt(source -> source.getMinConcordantFragmentSize()).min().getAsInt();
	}
	@Override
	public int getMaxReadLength() {
		return all.stream().mapToInt(source -> source.getMaxReadLength()).max().getAsInt();
	}
	@Override
	public int getMaxReadMappedLength() {
		return all.stream().mapToInt(source -> source.getMaxReadMappedLength()).max().getAsInt();
	}
}