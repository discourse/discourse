# frozen_string_literal: true

require 'rails_helper'

describe CalendarsController do
  fab!(:user) { Fabricate(:user) }
  fab!(:post) { Fabricate(:post) }

  describe "#download" do
    it "returns an .ics file for dates" do
      sign_in(user)
      get "/calendars.ics", params: {
        post_id: post.id,
        title: "event title",
        dates: {
          "0": {
            starts_at: "2021-10-12T15:00:00.000Z",
            ends_at: "2021-10-13T16:30:00.000Z",
          },
          "1": {
            starts_at: "2021-10-15T17:00:00.000Z",
            ends_at: "2021-10-15T18:00:00.000Z",
          },
        }
      }
      expect(response.status).to eq(200)
      expect(response.body).to eq(<<~ICS)
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Discourse//#{Discourse.current_hostname}//#{Discourse.full_version}//EN
        BEGIN:VEVENT
        UID:post_##{post.id}_#{"2021-10-12T15:00:00.000Z".to_datetime.to_i}_#{"2021-10-13T16:30:00.000Z".to_datetime.to_i}@#{Discourse.current_hostname}
        DTSTAMP:#{Time.now.utc.strftime("%Y%m%dT%H%M%SZ")}
        DTSTART:#{"2021-10-12T15:00:00.000Z".to_datetime.strftime("%Y%m%dT%H%M%SZ")}
        DTEND:#{"2021-10-13T16:30:00.000Z".to_datetime.strftime("%Y%m%dT%H%M%SZ")}
        SUMMARY:event title
        DESCRIPTION:Hello world
        URL:#{Discourse.base_url}/t/-/#{post.topic_id}/#{post.post_number}
        END:VEVENT
        BEGIN:VEVENT
        UID:post_##{post.id}_#{"2021-10-15T17:00:00.000Z".to_datetime.to_i}_#{"2021-10-15T18:00:00.000Z".to_datetime.to_i}@#{Discourse.current_hostname}
        DTSTAMP:#{Time.now.utc.strftime("%Y%m%dT%H%M%SZ")}
        DTSTART:#{"2021-10-15T17:00:00.000Z".to_datetime.strftime("%Y%m%dT%H%M%SZ")}
        DTEND:#{"2021-10-15T18:00:00.000Z".to_datetime.strftime("%Y%m%dT%H%M%SZ")}
        SUMMARY:event title
        DESCRIPTION:Hello world
        URL:#{Discourse.base_url}/t/-/#{post.topic_id}/#{post.post_number}
        END:VEVENT
        END:VCALENDAR
      ICS
    end
  end
end
