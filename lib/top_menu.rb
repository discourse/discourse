# frozen_string_literal: true

module TopMenu
  class << self
    def choices
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

    def crawler_homepage_choices
      choices & (Discourse.anonymous_filters.map(&:to_s) + %w[new categories])
    end

    def homepage_choices
      choices | (Discourse.filters.map(&:to_s) - %w[unread])
    end
  end
end
