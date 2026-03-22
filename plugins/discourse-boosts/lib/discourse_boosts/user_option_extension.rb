# frozen_string_literal: true

module DiscourseBoosts
  module UserOptionExtension
    def self.prepended(base)
      base.validates :boost_notifications_level, inclusion: { in: 0..2 }
    end
  end
end
