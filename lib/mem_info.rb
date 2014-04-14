class MemInfo

  # Total memory in kb. On Mac OS uses "sysctl", elsewhere expects the system has /proc/meminfo.
  # Returns nil if it cannot be determined.
  def mem_total
    @mem_total ||=
      begin
        system = `uname`.strip
        if system == "Darwin"
          s = `sysctl -n hw.memsize`.strip
          s.to_i / 1.kilobyte
        else
          s = `grep MemTotal /proc/meminfo`
          /(\d+)/.match(s)[0].try(:to_i)
        end
      rescue
        nil
      end
  end

end
