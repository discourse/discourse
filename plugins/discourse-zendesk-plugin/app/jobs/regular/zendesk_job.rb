# frozen_string_literal: true

module Jobs
  class ZendeskJob < ::Jobs::Base
    sidekiq_options backtrace: true
    include ::DiscourseZendeskPlugin::Helper

    def execute(args)
      return unless SiteSetting.zendesk_enabled?
      return if SiteSetting.zendesk_jobs_email.blank? || SiteSetting.zendesk_jobs_api_token.blank?

      if args[:post_id].present?
        push_post!(args[:post_id])
      elsif args[:topic_id].present?
        push_topic!(args[:topic_id])
      end
    end

    private

    def push_topic!(topic_id)
      topic = Topic.find_by(id: topic_id)
      return if !DiscourseZendeskPlugin::Helper.autogeneration_category?(topic.category_id)
      if topic.present? &&
           DiscourseZendeskPlugin::Helper.autogeneration_category?(topic.category_id)
        topic.post_ids.each { |post_id| push_post!(post_id) }
      end
    end

    def push_post!(post_id)
      post = Post.find_by(id: post_id)
      return if !post || post.user_id < 1
      return if post.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD].present?
      return if !DiscourseZendeskPlugin::Helper.autogeneration_category?(post.topic.category_id)
      return if !SiteSetting.zendesk_job_push_all_posts? && post.post_number > 1

      ticket_id = post.topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD]
      if ticket_id.present?
        add_comment(post, ticket_id) if comment_eligible_for_sync?(post)
      else
        create_ticket(post)
      end
    end
  end
end
