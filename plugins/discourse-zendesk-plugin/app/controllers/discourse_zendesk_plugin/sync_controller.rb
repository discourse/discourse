# frozen_string_literal: true

module DiscourseZendeskPlugin
  class SyncController < ApplicationController
    include ::DiscourseZendeskPlugin::Helper

    requires_plugin ::DiscourseZendeskPlugin::PLUGIN_NAME

    layout false
    before_action :zendesk_token_valid?, only: :webhook
    skip_before_action :check_xhr,
                       :preload_json,
                       :verify_authenticity_token,
                       :redirect_to_login_if_required,
                       only: :webhook

    def webhook
      unless SiteSetting.zendesk_enabled? && SiteSetting.sync_comments_from_zendesk
        return render json: failed_json, status: 422
      end

      ticket_id = params[:ticket_id]
      raise Discourse::InvalidParameters.new(:ticket_id) if ticket_id.blank?
      topic = Topic.find_by_id(params[:topic_id])
      raise Discourse::InvalidParameters.new(:topic_id) if topic.blank?
      return if !DiscourseZendeskPlugin::Helper.autogeneration_category?(topic.category_id)

      user = User.find_by_email(params[:email]) || Discourse.system_user
      latest_comment = get_latest_comment(ticket_id)
      if latest_comment.present?
        existing_comment =
          PostCustomField.where(
            name: ::DiscourseZendeskPlugin::ZENDESK_ID_FIELD,
            value: latest_comment.id,
          ).first

        if existing_comment.blank?
          post = topic.posts.create!(user: user, raw: latest_comment.body)
          update_post_custom_fields(post, latest_comment)
        end
      end

      render json: {}, status: 204
    end

    private

    def zendesk_token_valid?
      params.require(:token)

      if SiteSetting.zendesk_incoming_webhook_token.blank? ||
           SiteSetting.zendesk_incoming_webhook_token != params[:token]
        raise Discourse::InvalidAccess.new
      end
    end
  end
end
