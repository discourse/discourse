# TODO:
# a mechanism to iterate through errors in reverse
# async logging should queue, if dupe stack traces are found in batch error should be merged into prev one

class ErrorLog

  @lock = Mutex.new

  def self.filename
    "#{Rails.root}/log/#{Rails.env}_errors.log"
  end

  def self.clear!(guid)
    raise NotImplementedError
  end

  def self.clear_all!()
    File.delete(ErrorLog.filename) if File.exists?(ErrorLog.filename)
  end

  def self.report_async!(exception, controller, request, user)
    Thread.new do
      report!(exception, controller, request, user)
    end
  end

  def self.report!(exception, controller, request, user)
    add_row!(
      date: DateTime.now,
      guid: SecureRandom.uuid,
      user_id: user && user.id,
      parameters: request && request.filtered_parameters.to_json,
      action: controller.action_name,
      controller: controller.controller_name,
      backtrace: sanitize_backtrace(exception.backtrace).join("\n"),
      message: exception.message,
      url: "#{request.protocol}#{request.env["HTTP_X_FORWARDED_HOST"] || request.env["HTTP_HOST"]}#{request.fullpath}",
      exception_class: exception.class.to_s
    )
  end

  def self.add_row!(hash)
    data = hash.to_xml(skip_instruct: true)
    # use background thread to write the log cause it may block if it gets backed up
    @lock.synchronize do
      File.open(filename, "a") do |f|
        f.flock(File::LOCK_EX)
        f.write(data)
        f.close
      end
    end
  end


  def self.each(&blk)
    skip(0, &blk)
  end

  def self.skip(skip=0)
    pos = 0
    return [] unless File.exists?(filename)

    loop do
      lines = ""
      File.open(self.filename, "r") do |f|
        f.flock(File::LOCK_SH)
        f.pos = pos
        while !f.eof?
          line = f.readline
          lines << line
          break if line.starts_with? "</hash>"
        end
        pos = f.pos
      end
      if lines != "" && skip == 0
        h = {}
        e = Nokogiri.parse(lines).children[0]
        e.children.each do |inner|
          h[inner.name] = inner.text
        end
        yield h
      end
      skip-=1 if skip > 0
      break if lines == ""
    end
  end

  private

  def self.sanitize_backtrace(trace)
    re = Regexp.new(/^#{Regexp.escape(Rails.root.to_s)}/)
    trace.map { |line| Pathname.new(line.gsub(re, "[RAILS_ROOT]")).cleanpath.to_s }
  end

end
