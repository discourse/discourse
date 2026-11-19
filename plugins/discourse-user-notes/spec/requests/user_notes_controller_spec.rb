# frozen_string_literal: true

require "rails_helper"

describe DiscourseUserNotes::UserNotesController do
  fab!(:moderator)
  fab!(:user)
  fab!(:admin)

  before { SiteSetting.user_notes_enabled = true }

  describe "#create" do
    it "does not create a notification by default" do
      Jobs.run_immediately!

      expect { DiscourseUserNotes.add_note(user, "Staff note", admin.id) }.not_to change {
        Notification.where(notification_type: Notification.types[:staff_user_note]).count
      }
    end

    it "notifies configured staff once and hides the notice after they lose their role" do
      Jobs.run_immediately!
      group = Fabricate(:group)
      [admin, moderator, user].each { |member| group.add(member) }
      SiteSetting.user_notes_notification_groups = group.id.to_s
      note = DiscourseUserNotes.add_note(user, "Staff-only text", admin.id)
      Jobs::NotifyStaffUserNote.new.execute(user_id: user.id, note_id: note[:id])

      notices = Notification.where(notification_type: Notification.types[:staff_user_note])
      expect(notices.pluck(:user_id)).to eq([moderator.id])
      expect(notices.first.data_hash).to eq(
        "username" => user.username,
        "user_note_id" => note[:id],
      )

      sign_in(moderator)
      get "/notifications.json"
      expect(response.parsed_body["notifications"].pluck("id")).to include(notices.first.id)

      SiteSetting.user_notes_enabled = false
      get "/notifications.json"
      expect(response.parsed_body["notifications"]).to be_empty

      SiteSetting.user_notes_enabled = true
      moderator.update!(moderator: false)
      [true, false].each do |recent|
        get "/notifications.json", params: { recent: recent ? true : nil }
        expect(response.status).to eq(200)
        expect(response.parsed_body["notifications"]).to be_empty
      end
    end

    it "rejects notes longer than the maximum post length" do
      SiteSetting.max_post_length = 10
      sign_in(moderator)

      post "/user_notes",
           params: {
             user_note: {
               user_id: user.id,
               raw: "a" * 11,
             },
           },
           headers: {
             "ACCEPT" => "application/json",
           }

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to contain_exactly(
        I18n.t("user_notes.note_too_long", max: SiteSetting.max_post_length),
      )
      expect(DiscourseUserNotes.notes_for(user.id)).to be_empty
    end

    context "when post_id references a PM the moderator cannot see" do
      fab!(:pm_topic) do
        Fabricate(
          :private_message_topic,
          user: admin,
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: admin)],
        )
      end
      fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: admin) }

      it "does not leak post_url or post_title for the inaccessible post" do
        sign_in(moderator)

        post "/user_notes",
             params: {
               user_note: {
                 user_id: user.id,
                 raw: "probe note",
                 post_id: pm_post.id,
               },
             },
             headers: {
               "ACCEPT" => "application/json",
             }

        expect(response.status).to eq(200)
        json = response.parsed_body
        serialized = json.is_a?(Array) ? json.first : json

        expect(serialized["post_url"]).to be_nil
        expect(serialized["post_title"]).to be_nil

        notes = DiscourseUserNotes.notes_for(user.id)
        expect(notes.last["post_id"]).to be_nil
      end
    end
  end

  describe "#index" do
    it "requires moderation scope for the scoped notifications API" do
      Jobs.run_immediately!
      group = Fabricate(:group)
      group.add(moderator)
      SiteSetting.user_notes_notification_groups = group.id.to_s
      DiscourseUserNotes.add_note(user, "Staff-only text", admin.id)
      token = McpOauthAccessToken.new(user: moderator, scopes: [DiscourseMcp::Scopes::CONTENT_READ])

      result =
        DiscourseMcp::Tools::ListNotifications.call(
          arguments: {
          },
          request_context: DiscourseMcp::RequestContext.new(token),
        ).fetch(:structuredContent)
      expect(result[:notifications]).to be_empty

      token.scopes += [DiscourseMcp::Scopes::MODERATION_READ]
      result =
        DiscourseMcp::Tools::ListNotifications.call(
          arguments: {
          },
          request_context: DiscourseMcp::RequestContext.new(token),
        ).fetch(:structuredContent)
      expect(result[:notifications].pluck(:notification_type)).to eq(
        [Notification.types[:staff_user_note]],
      )
    end

    context "when a note references a PM the moderator cannot see" do
      fab!(:pm_topic) do
        Fabricate(
          :private_message_topic,
          user: admin,
          topic_allowed_users: [Fabricate.build(:topic_allowed_user, user: admin)],
        )
      end
      fab!(:pm_post) { Fabricate(:post, topic: pm_topic, user: admin) }

      before { DiscourseUserNotes.add_note(user, "old note", admin.id, post_id: pm_post.id) }

      it "does not leak post_url or post_title for inaccessible posts" do
        sign_in(moderator)

        get "/user_notes", params: { user_id: user.id }, headers: { "ACCEPT" => "application/json" }

        expect(response.status).to eq(200)
        json = response.parsed_body
        note = json["user_notes"].first

        expect(note["post_url"]).to be_nil
        expect(note["post_title"]).to be_nil
      end
    end
  end
end
