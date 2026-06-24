# frozen_string_literal: true

module TopMenu
  def self.choices
    base = %w[latest new unseen top categories read posted bookmarks hot]
    begin
      base << "unread" unless UpcomingChanges.enabled?(:enable_unified_new)
    rescue ArgumentError
      # During initial settings load, the enable_unified_new setting may not
      # be registered yet. Default to including unread in that case.
      base << "unread"
    end
    base
  end
end
