# frozen_string_literal: true

class RedeliveringWebhookEvent < ActiveRecord::Base
  belongs_to :web_hook_event
end

# == Schema Information
#
# Table name: redelivering_webhook_events
#
#  id                :bigint           not null, primary key
#  web_hook_event_id :bigint           not null
#  processing        :boolean          default(FALSE), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#
# Indexes
#
#  index_redelivering_webhook_events_on_web_hook_event_id  (web_hook_event_id)
#
