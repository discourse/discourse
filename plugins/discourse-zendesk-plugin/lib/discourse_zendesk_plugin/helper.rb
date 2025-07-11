# frozen_string_literal: true

module DiscourseZendeskPlugin
  module Helper
    def zendesk_client
      ::ZendeskAPI::Client.new do |config|
        config.url = SiteSetting.zendesk_url
        config.username = SiteSetting.zendesk_jobs_email
        config.token = SiteSetting.zendesk_jobs_api_token
      end
    end

    def self.autogeneration_category?(category_id)
      return false if category_id.blank?

      if SiteSetting.zendesk_autogenerate_all_categories?
        true
      else
        SiteSetting.zendesk_autogenerate_categories.split("|").include?(category_id.to_s)
      end
    end

    def create_ticket(post)
      zendesk_user_id = fetch_submitter(post.user)&.id
      if zendesk_user_id.present?
        ticket =
          zendesk_client.tickets.create(
            subject: post.topic.title,
            comment: {
              html_body: get_post_content(post),
            },
            requester_id: zendesk_user_id,
            submitter_id: zendesk_user_id,
            priority: "normal",
            tags: SiteSetting.zendesk_tags.split("|"),
            external_id: post.topic.id,
            custom_fields: [
              imported_from: ::Discourse.current_hostname,
              external_id: post.topic.id,
              imported_by: "discourse_zendesk_plugin",
            ],
          )

        if ticket.present?
          update_topic_custom_fields(post.topic, ticket)
          update_post_custom_fields(post, ticket.comments.first)
        end
      end
    end

    def comment_eligible_for_sync?(post)
      if SiteSetting.zendesk_job_push_only_author_posts?
        return false if post.blank? || post.user.blank?
        return false if post.topic.blank? || post.topic.user.blank?

        post.user.id == post.topic.user.id
      else
        true
      end
    end

    def add_comment(post, ticket_id)
      return if post.blank? || post.user.blank?
      zendesk_user_id = fetch_submitter(post.user)&.id

      if zendesk_user_id.present?
        ticket = ZendeskAPI::Ticket.new(zendesk_client, id: ticket_id)
        ticket.comment = { html_body: get_post_content(post), author_id: zendesk_user_id }
        ticket.save
        update_post_custom_fields(post, ticket.comments.last)
      end
    end

    def get_latest_comment(ticket_id)
      ticket = ZendeskAPI::Ticket.new(zendesk_client, id: ticket_id)
      last_public_comment = nil

      ticket.comments.all! { |comment| last_public_comment = comment if comment.public }
      last_public_comment
    end

    def update_topic_custom_fields(topic, ticket)
      topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = ticket["id"]
      topic.custom_fields[::DiscourseZendeskPlugin::ZENDESK_API_URL_FIELD] = ticket["url"]
      topic.save_custom_fields
    end

    def update_post_custom_fields(post, comment)
      return if comment.blank?

      post.custom_fields[::DiscourseZendeskPlugin::ZENDESK_ID_FIELD] = comment["id"]
      post.save_custom_fields
    end

    def fetch_submitter(user)
      result = zendesk_client.users.search(query: user.email)
      return result.first if result.present? && result.size == 1
      zendesk_client.users.create(
        name: (user.name.present? ? user.name : user.username),
        email: user.email,
        verified: true,
        role: "end-user",
      )
    end

    def get_post_content(post)
      style = Email::Styles.new(post.cooked)
      style.format_basic
      style.format_html
      html = style.to_html

      "#{html} \n\n [<a href='#{post.full_url}'>Discourse post</a>]"
    end
  end
end
