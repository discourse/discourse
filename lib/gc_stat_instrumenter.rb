# frozen_string_literal: true

class GCStatInstrumenter
  def self.instrument
    start_gc_stat = GC.stat
    yield
    end_gc_stat = GC.stat

    {
      gc: {
        time: (end_gc_stat[:time] - start_gc_stat[:time]) / 1000.0,
        major_count: end_gc_stat[:major_gc_count] - start_gc_stat[:major_gc_count],
        minor_count: end_gc_stat[:minor_gc_count] - start_gc_stat[:minor_gc_count],
      },
    }
  end
end
