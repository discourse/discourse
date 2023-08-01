# frozen_string_literal: true

module Chat
  class WebhookEventSerializer < ApplicationSerializer
    attributes :username, :emoji
  end
end
