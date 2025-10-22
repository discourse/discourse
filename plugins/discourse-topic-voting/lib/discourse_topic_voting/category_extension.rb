# frozen_string_literal: true

module DiscourseTopicVoting
  module CategoryExtension
    extend ActiveSupport::Concern

    prepended do
      has_one :discourse_topic_voting_category_setting,
              class_name: "DiscourseTopicVoting::CategorySetting",
              dependent: :destroy

      accepts_nested_attributes_for :discourse_topic_voting_category_setting, allow_destroy: true

      after_save :reset_voting_cache, if: -> { SiteSetting.topic_voting_enabled? }

      @allowed_voting_cache = DistributedCache.new("allowed_voting")
    end

    class_methods do
      def reset_voting_cache
        @allowed_voting_cache["allowed"] = DiscourseTopicVoting::CategorySetting.pluck(:category_id)
      end

      def can_vote?(category_id)
        return false if !SiteSetting.topic_voting_enabled

        (@allowed_voting_cache["allowed"] || reset_voting_cache).include?(category_id)
      end
    end

    protected

    def reset_voting_cache
      ::Category.reset_voting_cache
    end
  end
end
