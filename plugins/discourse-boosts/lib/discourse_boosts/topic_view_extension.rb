# frozen_string_literal: true

module DiscourseBoosts
  module TopicViewExtension
    def self.prepended(base)
      base.attr_accessor(:boosts_reviewables_by_target, :boosts_available_flags)
      base.memoize_for_posts(:boosts_reviewables_by_target)
    end
  end
end
