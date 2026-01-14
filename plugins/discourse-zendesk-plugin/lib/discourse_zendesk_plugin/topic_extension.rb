# frozen_string_literal: true

module DiscourseZendeskPlugin
  module TopicExtension
    def self.prepended(base)
      base.after_update :publish_to_zendesk
    end

    private

    def publish_to_zendesk
      return if saved_changes[:category_id].blank?

      old_category = Category.find_by(id: saved_changes[:category_id].first)
      new_category = Category.find_by(id: saved_changes[:category_id].last)

      old_cat_enabled = DiscourseZendeskPlugin::Helper.autogeneration_category?(old_category&.id)
      new_cat_enabled = DiscourseZendeskPlugin::Helper.autogeneration_category?(new_category&.id)

      # Do nothing if neither old or new category are enabled
      return nil if !old_cat_enabled && !new_cat_enabled

      # Do nothing if both categories are enabled
      return nil if old_cat_enabled && new_cat_enabled

      # enqueue job in future since after commit does not maintain changes hash
      Jobs.enqueue_in(5.seconds, :zendesk_job, topic_id: id)
    end
  end
end
