# frozen_string_literal: true

class WebHookEventTypesHook < ActiveRecord::Base
  belongs_to :web_hook_event_type
  belongs_to :web_hook
end

# == Schema Information
#
# Table name: web_hook_event_types_hooks
#
#  web_hook_id            :integer          not null
#  web_hook_event_type_id :integer          not null
#
# Indexes
#
#  idx_web_hook_event_types_hooks_on_ids  (web_hook_event_type_id,web_hook_id) UNIQUE
#
