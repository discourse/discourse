# frozen_string_literal: true

class RedeliveringWebhookEvent < ActiveRecord::Base
  belongs_to :web_hook_event
end
