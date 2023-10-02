# frozen_string_literal: true

module DiscourseAutomation
  class AppendLastCheckedByController < ApplicationController
    requires_plugin DiscourseAutomation::PLUGIN_NAME
    requires_login

    def post_checked
      post = Post.find(params[:post_id])
      guardian.ensure_can_edit!(post)

      topic = post.topic
      raise Discourse::NotFound if topic.blank?

      topic.custom_fields[DiscourseAutomation::TOPIC_LAST_CHECKED_BY] = current_user.username
      topic.custom_fields[DiscourseAutomation::TOPIC_LAST_CHECKED_AT] = Time.zone.now.to_s
      topic.save_custom_fields

      post.rebake!

      render json: success_json
    end
  end
end
