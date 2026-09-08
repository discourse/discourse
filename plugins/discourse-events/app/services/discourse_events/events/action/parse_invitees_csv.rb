# frozen_string_literal: true

require "csv"

module DiscourseEvents
  module Events
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
        rescue CSV::MalformedCSVError
          []
        end
      end
    end
  end
end
