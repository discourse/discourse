# frozen_string_literal: true

class AdminNoticeSerializer < ApplicationSerializer
  attributes :id, :priority, :message, :identifier
end
