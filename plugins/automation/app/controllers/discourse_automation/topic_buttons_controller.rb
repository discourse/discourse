# frozen_string_literal: true

module DiscourseAutomation
  class TopicButtonsController < ApplicationController
    requires_plugin DiscourseAutomation::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_automation
    before_action :ensure_topic

    def trigger
      button = DiscourseAutomation::TopicButton.new(@automation, topic: @topic, user: current_user)

      raise Discourse::InvalidAccess unless button.available?

      @automation.trigger!(button.context)

      render json: success_json
    end

    private

    def ensure_automation
      @automation = DiscourseAutomation::Automation.find_by(id: params[:id], enabled: true)

      raise Discourse::NotFound if @automation.blank?

      unless @automation.script == DiscourseAutomation::Scripts::MANUAL_TOPIC_BUTTON &&
               @automation.trigger == DiscourseAutomation::Triggers::TOPIC_MANUAL_BUTTON
        raise Discourse::InvalidAccess
      end
    end

    def ensure_topic
      @topic = Topic.find_by(id: params[:topic_id])

      raise Discourse::NotFound if @topic.blank?

      guardian.ensure_can_see!(@topic)
      guardian.ensure_can_trigger_automation!(@automation, @topic)
    end
  end
end
