# frozen_string_literal: true

module DiscourseZendeskPlugin
  class IssuesController < ApplicationController
    include DiscourseZendeskPlugin::Helper

    requires_plugin PLUGIN_NAME
    requires_login

    def create
      topic = Topic.find(params[:topic_id])
      guardian.ensure_can_create_zendesk_ticket!(topic)

      if topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD].blank?
        create_ticket(topic.first_post)
      end

      topic_view = ::TopicView.new(topic.id, current_user)
      topic_view_serializer =
        ::TopicViewSerializer.new(topic_view, scope: topic_view.guardian, root: false)
      render_json_dump topic_view_serializer
    end
  end
end
