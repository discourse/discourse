# frozen_string_literal: true

class RakeHelpers
  def self.print_status_with_label(label, current, max)
    print "\r\033[K%s%9d / %d (%5.1f%%)" % [label, current, max, ((current.to_f / max.to_f) * 100).round(1)]
  end

  def self.print_status(current, max)
    print "\r\033[K%9d / %d (%5.1f%%)" % [current, max, ((current.to_f / max.to_f) * 100).round(1)]
  end
end
