# frozen_string_literal: true

module DiscourseZendeskPlugin
  module PostExtension
    def self.prepended(base)
      base.after_commit :generate_zendesk_ticket, on: [:create]
    end

    private

    def generate_zendesk_ticket
      return unless SiteSetting.zendesk_enabled?

      has_zendesk_ticket = topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD].present?
      unless has_zendesk_ticket ||
               DiscourseZendeskPlugin::Helper.autogeneration_category?(topic.category_id)
        return
      end

      Jobs.enqueue_in(5.seconds, :zendesk_job, post_id: id)
    end
  end
end
