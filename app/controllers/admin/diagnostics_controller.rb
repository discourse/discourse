class Admin::DiagnosticsController < Admin::AdminController
  layout false
  skip_before_filter :check_xhr

  def memory_stats
    text = nil

    if params.key?(:diff)
      if !File.exists?(snapshot_filename)
        text = "No initial snapshot exists"
      else
        filename = snapshot_filename + ".new"
        snapshot_current_process(filename)

        text = compare(snapshot_filename, filename)
      end
    elsif params.key?(:snapshot)
      snapshot_current_process
      text = "Writing snapshot to: #{snapshot_filename}\n\nTo get a diff use ?diff=1"
    else
      text = memory_report(class_report: params.key?(:full))
    end

    render text: text, content_type: Mime::TEXT
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

  protected

  def compare(from, to)
    from = Marshal::load(IO.binread(from));
    to = Marshal::load(IO.binread(to));

    diff = from - to

    require 'objspace'
    diff = diff.map do |id|
      ObjectSpace._id2ref(id) rescue nil
    end.compact!

    report = "#{diff.length} objects have leaked\n"

    report << "Summary:\n"

    summary = {}
    diff.each do |obj|
      begin
        summary[obj.class] ||= 0
        summary[obj.class] += 1
      rescue
        # don't care
      end
    end

    report << summary.sort{|a,b| b[1] <=> a[1]}[0..50].map{|k,v|
      "#{k}: #{v}"
    }.join("\n")

    report << "\n\nSample Items:\n"

    diff[0..5000].each do |v|
      report << "#{v.class}: #{String === v ? v[0..300] : (40 + ObjectSpace.memsize_of(v)).to_s + " bytes"}\n" rescue nil
    end

    report
  end

  def snapshot_path
    "#{Rails.root}/tmp/mem_snapshots"
  end

  def snapshot_filename
    "#{snapshot_path}/#{Process.pid}.snapshot"
  end

  def snapshot_current_process(filename=nil)
    filename ||= snapshot_filename
    pid=fork do
      snapshot(filename)
    end

    Process.wait(pid)
  end

  def snapshot(filename)
    require 'objspace'
    FileUtils.mkdir_p snapshot_path
    object_ids = []

    full_gc

    ObjectSpace.each_object do |o|
      begin
        object_ids << o.object_id
      rescue
        # skip
      end
    end

    IO.binwrite(filename, Marshal::dump(object_ids))
  end

  def memory_report(opts={})
    begin
      # ruby 2.1
      GC.start(full_mark: true)
    rescue
      GC.start
    end


    classes = {}
    large_objects = []

    if opts[:class_report]
      require 'objspace'
      ObjectSpace.each_object do |o|
        begin
          classes[o.class] ||= 0
          classes[o.class] += 1
          if (size = ObjectSpace.memsize_of(o)) > 200
            large_objects << [size, o]
          end
        rescue
          # all sorts of stuff can happen here BasicObject etc.
          classes[:unknown] ||= 0
          classes[:unknown] += 1
        end
      end
      classes = classes.sort{|a,b| b[1] <=> a[1]}[0..40].map{|klass, count| "#{klass}: #{count}"}

      classes << "\nLarge Objects (#{large_objects.length} larger than 200 bytes total size #{large_objects.map{|x,_| x}.sum}):\n"

      classes += large_objects.sort{|a,b| b[0] <=> a[0]}[0..800].map do |size,object|
        rval = "#{object.class}: size #{size}"
        rval << " " << object.to_s[0..500].gsub("\n", "") if (String === object) || (Regexp === object)
        rval << "\n"
        rval
      end
    end

    stats = GC.stat.map{|k,v| "#{k}: #{v}"}
    counts = ObjectSpace.count_objects.sort{|a,b| b[1] <=> a[1] }.map{|k,v| "#{k}: #{v}"}



    <<TEXT
#{`hostname`.strip} pid:#{Process.pid} #{`cat /proc/#{Process.pid}/cmdline`.strip.gsub(/[^a-z1-9\/]/i, ' ')}

GC STATS:
#{stats.join("\n")}

Objects:
#{counts.join("\n")}

Process Info:
#{`cat /proc/#{Process.pid}/status`}

Classes:
#{classes.length > 0 ? classes.join("\n") : "Class report omitted use ?full=1 to include it"}

TEXT

  end


  def full_gc
    # gc start may not collect everything
    GC.start while new_count = decreased_count(new_count)
  end

  def decreased_count(old)
    count = count_objects
    if !old || count < old
      count
    else
      nil
    end
  end

  def count_objects
    i = 0
    ObjectSpace.each_object do |obj|
      i += 1
    end
  end
end
