# frozen_string_literal: true

module DiscourseEvents
  class BaseController < ::ApplicationController
    requires_plugin DiscourseEvents::PLUGIN_NAME
    before_action :ensure_discourse_post_event_enabled

    private

    def ensure_discourse_post_event_enabled
      raise Discourse::NotFound if !SiteSetting.discourse_post_event_enabled
    end
  end
end
