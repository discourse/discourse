class Admin::DiagnosticsController < Admin::AdminController
  layout false
  skip_before_filter :check_xhr

  def memory_stats

    begin
      # ruby 2.1
      GC.start(full_mark: true)
    rescue
      GC.start
    end

    stats = GC.stat.map{|k,v| "#{k}: #{v}"}
    counts = ObjectSpace.count_objects.map{|k,v| "#{k}: #{v}"}

    render text: "GC STATS:\n#{stats.join("\n")} \n\nObjects:\n#{counts.join("\n")}",
      content_type: Mime::TEXT

  end

  def dump_heap
    begin
      # ruby 2.1
      GC.start(full_mark: true)
      require 'objspace'

      io = File.open("discourse-heap-#{SecureRandom.hex(3)}.json",'w')
      ObjectSpace.dump_all(:output => io)
      io.close

      render text: "HEAP DUMP:\n#{io.path}", content_type: Mime::TEXT
    rescue
      render text: "HEAP DUMP:\nnot supported", content_type: Mime::TEXT
    end
  end
end
