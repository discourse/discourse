# frozen_string_literal: true

class WebHookEventTypesHook < ActiveRecord::Base
  belongs_to :web_hook_event_type
  belongs_to :web_hook
end
