class Admin::DiagnosticsController < Admin::AdminController
  layout false
  skip_before_filter :check_xhr

  def memory_stats

    stats = GC.stat.map{|k,v| "#{k}: #{v}"}
    counts = ObjectSpace.count_objects.map{|k,v| "#{k}: #{v}"}

    render text: "GC STATS:\n#{stats.join("\n")} \n\nObjects:\n#{counts.join("\n")}",
      content_type: Mime::TEXT

  end
end
