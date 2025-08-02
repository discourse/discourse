# frozen_string_literal: true

class RakeHelpers
  def self.print_status_with_label(label, current, max)
    return if Rails.env.test? && !ENV["RAILS_ENABLE_TEST_LOG"]
    print "\r\033[K%s%9d / %d (%5.1f%%)" %
            [label, current, max, ((current.to_f / max.to_f) * 100).round(1)]
  end

  def self.print_status(current, max)
    return if Rails.env.test? && !ENV["RAILS_ENABLE_TEST_LOG"]
    print "\r\033[K%9d / %d (%5.1f%%)" % [current, max, ((current.to_f / max.to_f) * 100).round(1)]
  end
end
