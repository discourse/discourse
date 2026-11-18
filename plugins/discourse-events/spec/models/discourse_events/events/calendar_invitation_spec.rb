# frozen_string_literal: true

RSpec.describe DiscourseEvents::Events::CalendarInvitation do
  fab!(:user)
  fab!(:event)

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.event_calendar_invitations_enabled = true
    SiteSetting.event_calendar_invitations_organizer = "calendar@example.com"
    SiteSetting.disable_emails = "no"
    ActionMailer::Base.deliveries.clear
  end

  def invite
    DiscourseEvents::Events::Invite.call(
      guardian: event.post.user.guardian,
      params: {
        event_id: event.id,
        invites: [user.username],
      },
    )
    described_class.find_by!(event_id: event.id, user_id: user.id)
  end

  def delivered_calendar
    Mail
      .read_from_string(ActionMailer::Base.deliveries.last.encoded)
      .attachments
      .find { |attachment| attachment.mime_type == "text/calendar" }
  end

  describe "inviting individual users" do
    it "sends a recipient-specific calendar REQUEST through the core sender once, including on retry" do
      invitation = invite
      Jobs::DeliverEventCalendarInvitation.new.execute(invitation_id: invitation.id)
      invite
      Jobs::DeliverEventCalendarInvitation.new.execute(invitation_id: invitation.id)

      expect(ActionMailer::Base.deliveries.size).to eq(1)
      message = ActionMailer::Base.deliveries.last
      expect(message.to).to eq([user.email])
      expect(message.reply_to).to eq([invitation.organizer])
      expect(message[Email::MessageBuilder::ALLOW_REPLY_BY_EMAIL_HEADER]).to be_nil
      expect(message.content_type).to start_with("multipart/mixed")
      expect(message.text_part.body.decoded).to include(event.post.full_url)
      expect(message.html_part).to be_present
      expect(delivered_calendar.content_type_parameters["method"]).to eq("REQUEST")
      expect(delivered_calendar.body.decoded).to include(
        "METHOD:REQUEST\r\n",
        "UID:#{invitation.uid}\r\n",
        "SEQUENCE:0\r\n",
        "ORGANIZER:mailto:calendar@example.com\r\n",
        "ATTENDEE;RSVP=TRUE:mailto:#{user.email}\r\n",
      )
      expect(invitation.reload.delivered_sequence).to eq(0)
    end

    it "does not backfill invitations when the setting is enabled" do
      SiteSetting.event_calendar_invitations_enabled = false
      expect { described_class.invite!(event, user) }.not_to change { described_class.count }
      SiteSetting.event_calendar_invitations_enabled = true
      event.update!(name: "New event name")
      expect(described_class.count).to eq(0)
    end

    it "requires an organizer and excludes recurring or past events" do
      SiteSetting.event_calendar_invitations_organizer = ""
      described_class.invite!(event, user)
      SiteSetting.event_calendar_invitations_organizer = "calendar@example.com"
      event.update!(recurrence: "every_week")
      described_class.invite!(event, user)
      event.update!(recurrence: nil, original_starts_at: 1.day.ago)
      described_class.invite!(event, user)
      expect(described_class.count).to eq(0)
    end

    it "does not send calendar email through group and bulk notification paths" do
      Fabricate(:post_event_invitee, event: event, user: user)
      event.notify_invitees!
      expect(described_class.count).to eq(0)
    end

    it "shares the original identity with later recipients after an organizer setting change" do
      first = invite
      SiteSetting.event_calendar_invitations_organizer = "new-calendar@example.com"
      another_user = Fabricate(:user)
      described_class.invite!(event, another_user)
      second = described_class.find_by!(user_id: another_user.id)
      expect([second.uid, second.organizer]).to eq([first.uid, first.organizer])
    end

    it "does not leak other attendees' addresses" do
      other_user = Fabricate(:user)
      described_class.invite!(event, other_user)
      invitation = invite
      invitation.deliver!
      expect(delivered_calendar.body.decoded.scan(/^ATTENDEE.*$/).size).to eq(1)
      expect(delivered_calendar.body.decoded).not_to include(other_user.email)
    end
  end

  describe "updating and cancelling" do
    it "keeps the UID and organizer, increases the sequence on reschedule, and ignores unrelated changes" do
      invitation = invite
      invitation.deliver!
      uid = invitation.uid
      event.update!(closed: true)
      invitation.reload.deliver!
      expect(ActionMailer::Base.deliveries.size).to eq(1)

      SiteSetting.event_calendar_invitations_organizer = "new-calendar@example.com"
      event.update!(original_starts_at: 3.days.from_now)
      invitation.reload.deliver!
      expect(ActionMailer::Base.deliveries.size).to eq(2)
      expect(delivered_calendar.body.decoded).to include("UID:#{uid}\r\n", "SEQUENCE:1\r\n")
      expect(invitation.organizer).to eq("calendar@example.com")
    end

    it "cancels after the event is destroyed using its last delivered details" do
      invitation = invite
      invitation.deliver!
      event.destroy!
      invitation.reload.deliver!
      invitation.reload.deliver!

      expect(ActionMailer::Base.deliveries.size).to eq(2)
      expect(delivered_calendar.content_type_parameters["method"]).to eq("CANCEL")
      expect(delivered_calendar.body.decoded).to include(
        "METHOD:CANCEL\r\n",
        "STATUS:CANCELLED\r\n",
        "UID:#{invitation.uid}\r\n",
        "SEQUENCE:1\r\n",
      )
    end

    it "cancels when event markup is removed from the post" do
      invitation = invite
      invitation.deliver!
      event.post.update!(raw: "The event was removed.")
      result = DiscourseEvents::Events::Event::SyncFromPost.call(params: { post_id: event.id })
      expect(result).to run_successfully
      invitation.reload.deliver!
      expect(delivered_calendar.content_type_parameters["method"]).to eq("CANCEL")
    end

    it "cancels on soft deletion and does not automatically reinvite on recovery" do
      invitation = invite
      invitation.deliver!
      DiscourseEvent.trigger(:post_destroyed, event.post)
      invitation.reload.deliver!
      expect(delivered_calendar.content_type_parameters["method"]).to eq("CANCEL")
      DiscourseEvent.trigger(:post_recovered, event.post)
      invitation.reload.deliver!
      expect(ActionMailer::Base.deliveries.size).to eq(2)
    end

    it "cancels when converted to a recurring event" do
      invitation = invite
      invitation.deliver!
      event.update!(recurrence: "every_week")
      invitation.reload.deliver!
      expect(delivered_calendar.content_type_parameters["method"]).to eq("CANCEL")
    end

    it "cancels when an attendance record is removed" do
      invitation = invite
      invitation.deliver!
      attendance = Fabricate(:post_event_invitee, event: event, user: user)
      attendance.destroy!
      invitation.reload.deliver!
      expect(delivered_calendar.content_type_parameters["method"]).to eq("CANCEL")
    end

    it "does not send a cancellation for an invitation never delivered" do
      invitation = invite
      event.destroy!
      invitation.reload.deliver!
      expect(ActionMailer::Base.deliveries).to be_empty
      expect(invitation.reload.delivered_sequence).to eq(invitation.sequence)
    end
  end

  describe "delivery safety" do
    it "respects opt-out, suspension, bounces, and global email disabling without marking delivery" do
      invitation = invite
      user.user_option.update!(email_level: UserOption.email_level_types[:never])
      invitation.reload.deliver!
      user.user_option.update!(email_level: UserOption.email_level_types[:always])
      user.update!(suspended_till: 1.day.from_now)
      invitation.reload.deliver!
      user.update!(suspended_till: nil)
      user.user_stat.update!(bounce_score: SiteSetting.bounce_score_threshold)
      invitation.reload.deliver!
      user.user_stat.update!(bounce_score: 0)
      SiteSetting.disable_emails = "yes"
      invitation.reload.deliver!
      SiteSetting.disable_emails = "non-staff"
      invitation.reload.deliver!
      expect(ActionMailer::Base.deliveries).to be_empty
      expect(invitation.reload.delivered_sequence).to eq(-1)
    end

    it "checks access at delivery time and cancels without revealing new private details" do
      invitation = invite
      invitation.deliver!
      old_snapshot = invitation.snapshot
      event.post.topic.update!(category: Fabricate(:private_category, group: Fabricate(:group)))
      event.update!(name: "Private replacement title")
      invitation.reload.deliver!
      expect(invitation.reload).to be_cancelled
      expect(invitation.snapshot).to eq(old_snapshot)
      expect(delivered_calendar.body.decoded).not_to include(event.name)
      expect(delivered_calendar.content_type_parameters["method"]).to eq("CANCEL")
    end

    it "recovers a lost queued job and stops requeueing a delivered revision" do
      invitation = invite
      Jobs::DeliverEventCalendarInvitation.jobs.clear

      Jobs::DeliverPendingEventCalendarInvitations.new.execute({})
      expect(Jobs::DeliverEventCalendarInvitation.jobs.size).to eq(1)
      expect(Jobs::DeliverEventCalendarInvitation.jobs.first["args"].first["invitation_id"]).to eq(
        invitation.id,
      )
      Jobs::DeliverEventCalendarInvitation.jobs.clear
      invitation.deliver!
      Jobs::DeliverPendingEventCalendarInvitations.new.execute({})
      expect(Jobs::DeliverEventCalendarInvitation.jobs).to be_empty
    end

    it "keeps failed delivery pending for a successful retry" do
      invitation = invite
      Mail::Message.any_instance.stubs(:deliver!).raises(IOError, "Connection interrupted")
      expect { invitation.deliver! }.to raise_error(IOError)
      expect(invitation.reload.delivered_sequence).to eq(-1)
      Mail::Message.any_instance.unstub(:deliver!)
      invitation.deliver!
      invitation.reload.deliver!
      expect(ActionMailer::Base.deliveries.size).to eq(1)
    end

    it "suppresses details when private email is enabled" do
      invitation = invite
      SiteSetting.private_email = true
      invitation.deliver!
      expect(ActionMailer::Base.deliveries).to be_empty
      expect(invitation.reload.delivered_sequence).to eq(-1)
    end

    it "does not deliver an initial request after the event starts" do
      invitation = invite
      freeze_time(event.original_starts_at + 1.minute)
      invitation.deliver!
      expect(ActionMailer::Base.deliveries).to be_empty
      expect(invitation.reload).to be_cancelled
    end

    it "rechecks organizer routing at delivery time" do
      invitation = invite
      Fabricate(:group, incoming_email: invitation.organizer)
      invitation.deliver!
      expect(ActionMailer::Base.deliveries).to be_empty
    end

    it "rejects invitations without topic access" do
      private_event = Fabricate(:private_event)
      described_class.invite!(private_event, user)
      expect(described_class.count).to eq(0)
    end

    it "stops delivery when the feature is disabled or the recipient changes email" do
      invitation = invite
      SiteSetting.event_calendar_invitations_enabled = false
      invitation.deliver!
      SiteSetting.event_calendar_invitations_enabled = true
      user.update!(email: "changed@example.com")
      invitation.reload.deliver!
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe "calendar serialization" do
    it "uses UTC for timed events, with a one-hour default duration" do
      event.update!(original_starts_at: Time.iso8601("2030-04-20T10:00:00-04:00"))
      invitation = invite
      invitation.deliver!
      expect(delivered_calendar.body.decoded).to include(
        "DTSTART:20300420T140000Z\r\n",
        "DTEND:20300420T150000Z\r\n",
      )
    end

    it "uses date-only all-day values with an exclusive end date" do
      event.update!(
        all_day: true,
        original_starts_at: Time.utc(2030, 4, 20),
        original_ends_at: Time.utc(2030, 4, 22),
      )
      invitation = invite
      invitation.deliver!
      expect(delivered_calendar.body.decoded).to include(
        "DTSTART;VALUE=DATE:20300420\r\n",
        "DTEND;VALUE=DATE:20300422\r\n",
      )
    end

    it "escapes property injection and folds on UTF-8 octet boundaries" do
      event.update!(name: "é" * 100, description: "A,B;C\\D\r\nATTENDEE:evil\rINJECTED:value")
      invitation = invite
      invitation.deliver!
      content = delivered_calendar.body.decoded.force_encoding(Encoding::UTF_8)
      expect(content).to be_valid_encoding
      expect(content.split("\r\n").map(&:bytesize).max).to be <= 75
      unfolded = content.gsub("\r\n ", "")
      expect(unfolded).to include("SUMMARY:#{event.name}\r\n")
      expect(unfolded).to include('A\,B\;C\\\\D\nATTENDEE:evil\nINJECTED:value')
      expect(unfolded.scan(/^ATTENDEE/).size).to eq(1)
    end
  end
end
