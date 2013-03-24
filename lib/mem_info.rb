class MemInfo
  # Total memory in kb. Only works on systems with /proc/meminfo.
  # Returns nil if it cannot be determined.
  def mem_total
    @mem_total ||= begin
      $&.try(:to_i) if grepped_mem_total_output =~ /(\d)+/
    end
  end

  private

  def grepped_mem_total_output
    `grep MemTotal /proc/meminfo 2>&1`
  end
end
