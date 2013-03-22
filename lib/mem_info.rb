class MemInfo

  # Total memory in kb. Only works on systems with /proc/meminfo.
  # Returns nil if it cannot be determined.
  def mem_total
    @mem_total ||= begin
      if s = `grep MemTotal /proc/meminfo`
        /(\d+)/.match(s)[0].try(:to_i)
      else
        nil
      end
    end
  end

end