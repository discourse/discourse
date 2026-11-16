# frozen_string_literal: true

RSpec.describe Live::CallsController do
  fab!(:caller) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:callee) { Fabricate(:user, trust_level: TrustLevel[2]) }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups =
      "#{Group::AUTO_GROUPS[:anonymous_users]}|#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.live_direct_calls_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
  end

  describe "#create" do
    it "creates an ephemeral room with both parties as moderators and rings the callee" do
      sign_in(caller)

      messages =
        MessageBus.track_publish { post "/live/calls.json", params: { username: callee.username } }
      alert_messages = messages.select { |m| m.channel == "/notification-alert/#{callee.id}" }
      ring_messages = messages.select { |m| m.channel == "/live/call-ring/#{callee.id}" }

      expect(response.status).to eq(200)

      room = Live::Room.find(response.parsed_body["room"]["id"])
      expect(room.ephemeral).to eq(true)
      expect(room.public).to eq(false)
      expect(room.name).to eq(
        I18n.t("live.call.room_name", caller: caller.username, callee: callee.username),
      )
      expect(room.moderator_ids).to contain_exactly(caller.id, callee.id)

      ringing = response.parsed_body["room"]["ringing"]
      expect(ringing.map { |entry| entry["user"]["id"] }).to contain_exactly(callee.id)
      expect(ringing.first["notified_at"]).to be_within(5).of(Time.current.to_i)

      invite = Live::Invite.find_by(room_id: room.id, user_id: callee.id)
      expect(invite.invited_by_id).to eq(caller.id)

      notification = callee.notifications.order(:id).last
      expect(notification.notification_type).to eq(Notification.types[:live_invitation])
      data = JSON.parse(notification.data)
      expect(data["call"]).to eq(true)
      expect(data["room_slug"]).to eq(room.slug)
      expect(data["display_username"]).to eq(caller.username)

      expect(alert_messages.size).to eq(1)
      expect(alert_messages.first.data[:translated_title]).to eq(
        I18n.t("live.call_notification.title", username: caller.username),
      )

      expect(ring_messages.size).to eq(1)
      ring = ring_messages.first
      expect(ring.user_ids).to contain_exactly(callee.id)
      expect(ring.data[:room_id]).to eq(room.id)
      expect(ring.data[:room_slug]).to eq(room.slug)
      expect(ring.data[:caller_username]).to eq(caller.username)
      expect(ring.data[:ring_seconds]).to eq(Live::RoomInviter::RING_SECONDS)
      expect(ring.data[:sent_at]).to be_within(5).of(Time.current.to_i)

      ringing_event =
        messages.find do |message|
          message.channel == "/live/rooms/#{room.id}" && message.data[:type] == "ringing"
        end
      expect(ringing_event).to be_present
      expect(ringing_event.data[:user][:id]).to eq(callee.id)
      expect(ringing_event.data[:notified_at]).to eq(ring.data[:sent_at])
    end

    it "gives the callee a peer's powers: joining and pulling others into the call" do
      sign_in(caller)

      post "/live/calls.json", params: { username: callee.username }

      room = Live::Room.find(response.parsed_body["room"]["id"])
      expect(callee.guardian.can_join_live_room?(room)).to eq(true)
      expect(callee.guardian.can_invite_to_live_room?(room)).to eq(true)
    end

    it "returns 404 for an unknown username" do
      sign_in(caller)

      post "/live/calls.json", params: { username: "no-such-user" }

      expect(response.status).to eq(404)
      expect(Live::Room.ephemeral.count).to eq(0)
    end

    it "rejects calling yourself" do
      sign_in(caller)

      post "/live/calls.json", params: { username: caller.username }

      expect(response.status).to eq(400)
      expect(Live::Room.ephemeral.count).to eq(0)
    end

    it "rejects a callee outside the allowed groups" do
      SiteSetting.live_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      outsider = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(caller)

      post "/live/calls.json", params: { username: outsider.username }

      expect(response.status).to eq(400)
      expect(Live::Room.ephemeral.count).to eq(0)
    end

    context "when the callee's preferences screen out the caller" do
      before { sign_in(caller) }

      it "returns 403 when the callee has muted the caller" do
        MutedUser.create!(user_id: callee.id, muted_user_id: caller.id)

        post "/live/calls.json", params: { username: callee.username }

        expect(response.status).to eq(403)
        expect(response.parsed_body["errors"]).to include(I18n.t("live.errors.cannot_call_user"))
        expect(Live::Room.ephemeral.count).to eq(0)
        expect(callee.notifications.count).to eq(0)
      end

      it "returns 403 when the callee has ignored the caller" do
        IgnoredUser.create!(
          user_id: callee.id,
          ignored_user_id: caller.id,
          expiring_at: 1.day.from_now,
        )

        post "/live/calls.json", params: { username: callee.username }

        expect(response.status).to eq(403)
        expect(Live::Room.ephemeral.count).to eq(0)
      end

      it "returns 403 when the callee does not accept personal messages" do
        callee.user_option.update!(allow_private_messages: false)

        post "/live/calls.json", params: { username: callee.username }

        expect(response.status).to eq(403)
        expect(Live::Room.ephemeral.count).to eq(0)
      end

      it "returns 403 when the callee only accepts personal messages from a list that omits the caller" do
        callee.user_option.update!(enable_allowed_pm_users: true)

        post "/live/calls.json", params: { username: callee.username }

        expect(response.status).to eq(403)
        expect(Live::Room.ephemeral.count).to eq(0)
      end

      it "connects the call when the caller is on the callee's allowed list" do
        callee.user_option.update!(enable_allowed_pm_users: true)
        AllowedPmUser.create!(user: callee, allowed_pm_user: caller)

        post "/live/calls.json", params: { username: callee.username }

        expect(response.status).to eq(200)
        expect(Live::Room.ephemeral.count).to eq(1)
      end
    end

    it "leaves a missed-call notification instead of ringing a callee in do not disturb" do
      callee.do_not_disturb_timings.create!(starts_at: Time.zone.now, ends_at: 1.hour.from_now)
      sign_in(caller)

      messages =
        MessageBus.track_publish { post "/live/calls.json", params: { username: callee.username } }

      expect(response.status).to eq(200)
      expect(messages.map(&:channel)).not_to include("/live/call-ring/#{callee.id}")

      # The caller still sees a normal outgoing ring so do-not-disturb status
      # is not revealed; the call simply goes unanswered.
      ringing = response.parsed_body["room"]["ringing"]
      expect(ringing.map { |entry| entry["user"]["id"] }).to contain_exactly(callee.id)

      notification = callee.notifications.order(:id).last
      expect(notification.notification_type).to eq(Notification.types[:live_invitation])
    end

    it "lets staff call a user whose preferences would screen out other callers" do
      SiteSetting.live_direct_calls_allowed_groups = Group::AUTO_GROUPS[:staff]
      admin = Fabricate(:admin)
      MutedUser.create!(user_id: callee.id, muted_user_id: admin.id)
      callee.user_option.update!(allow_private_messages: false)
      sign_in(admin)

      post "/live/calls.json", params: { username: callee.username }

      expect(response.status).to eq(200)
      expect(callee.notifications.count).to eq(1)
    end

    it "returns 403 when the caller is outside the direct-call groups (the default)" do
      SiteSetting.live_direct_calls_allowed_groups = ""
      sign_in(caller)

      post "/live/calls.json", params: { username: callee.username }

      expect(response.status).to eq(403)
      expect(Live::Room.ephemeral.count).to eq(0)
    end

    it "returns 403 when the caller lacks live-room access" do
      SiteSetting.live_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      outsider = Fabricate(:user, trust_level: TrustLevel[0])
      sign_in(outsider)

      post "/live/calls.json", params: { username: callee.username }

      expect(response.status).to eq(403)
      expect(Live::Room.ephemeral.count).to eq(0)
    end

    it "requires a logged-in user" do
      post "/live/calls.json", params: { username: callee.username }

      expect(response.status).to eq(403)
    end

    context "with rate limits enabled" do
      before do
        RateLimiter.enable
        sign_in(caller)
      end

      it "creates no ephemeral room once the daily invite budget is exhausted" do
        SiteSetting.live_max_invites_per_day = 1
        RateLimiter.new(caller, "live-invites-daily", 1, 1.day).performed!

        post "/live/calls.json", params: { username: callee.username }

        expect(response.status).to eq(429)
        expect(Live::Room.ephemeral.count).to eq(0)
        expect(callee.notifications.count).to eq(0)
      end

      it "destroys the room instead of orphaning it when the ring fails" do
        allow(Live::RoomInviter).to receive(:invite!).and_raise(
          RateLimiter::LimitExceeded.new(10, "live-invites-daily"),
        )

        post "/live/calls.json", params: { username: callee.username }

        expect(response.status).to eq(429)
        expect(Live::Room.ephemeral.count).to eq(0)
      end
    end

    it "rejects the call when the caller has too many live ephemeral rooms" do
      stub_const(Live::EphemeralRoomManager, :MAX_LIVE_ROOMS_PER_CREATOR, 1) do
        Live::EphemeralRoomManager.create!(creator: caller, name: "Ongoing call")
        sign_in(caller)

        post "/live/calls.json", params: { username: callee.username }

        expect(response.status).to eq(403)
        expect(Live::Room.ephemeral.count).to eq(1)
      end
    end
  end
end
