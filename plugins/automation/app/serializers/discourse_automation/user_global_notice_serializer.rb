# frozen_string_literal: true

module DiscourseAutomation
  class UserGlobalNoticeSerializer < ApplicationSerializer
    attributes :id, :notice, :level, :created_at, :updated_at, :identifier

    def level
      object.level || "info"
    end
  end
end
