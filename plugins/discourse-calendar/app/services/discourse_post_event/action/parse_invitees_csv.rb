# frozen_string_literal: true

require "csv"

module DiscoursePostEvent
  module Action
    class ParseInviteesCsv < Service::ActionBase
      DEFAULT_ATTENDANCE = "going"

      option :file

      def call
        invitees = []
        CSV.foreach(file.tempfile) do |identifier, attendance|
          next if identifier.blank?
          invitees << { identifier: identifier, attendance: attendance || DEFAULT_ATTENDANCE }
        end
        invitees
      rescue StandardError
        # A malformed or unreadable file yields no invitees; the empty result
        # is surfaced as an upload error downstream.
        []
      end
    end
  end
end
