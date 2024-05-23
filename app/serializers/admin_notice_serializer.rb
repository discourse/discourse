# frozen_string_literal: true

class AdminNoticeSerializer < ApplicationSerializer
  attributes :priority, :message, :identifier
end
