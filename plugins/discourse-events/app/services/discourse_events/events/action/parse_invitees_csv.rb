# frozen_string_literal: true

require "csv"

module DiscourseEvents
  module Events
    module Action
      class ParseInviteesCsv < Service::ActionBase
        DEFAULT_ATTENDANCE = "going"

        option :file

        def call
          max_invitees = SiteSetting.discourse_post_event_max_bulk_invitees
          invitees = []
          CSV.foreach(file.tempfile) do |identifier, attendance|
            break if invitees.size >= max_invitees
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
