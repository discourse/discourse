# frozen_string_literal: true

RSpec.describe Live::RoomsController do
  fab!(:room_owner) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:participant) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:other_participant) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:outsider) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) { Fabricate(:live_room, creator: room_owner, public: true) }

  before do
    SiteSetting.live_enabled = true
    SiteSetting.live_allowed_groups = "#{Group::AUTO_GROUPS[:logged_in_users]}"
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_reaction_for_like = "heart"
    SiteSetting.discourse_reactions_enabled_reactions = "clap|tada"

    Live::ParticipantTracker.add(room.id, participant.id)
    Live::ParticipantTracker.add(room.id, other_participant.id)
    @session_id = Live::ParticipantTracker.create_participant_session!(room.id, participant.id)
  end

  after { Live::ParticipantTracker.clear(room.id) }

  describe "#reaction" do
    it "broadcasts the reaction to everyone in the call" do
      sign_in(participant)

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          post "/live/rooms/#{room.id}/reaction.json",
               params: {
                 emoji: "clap",
                 participant_session_id: @session_id,
               }
        end

      expect(response.status).to eq(204)
      expect(messages.size).to eq(1)
      expect(messages.first.data).to eq(
        type: "reaction",
        room_id: room.id,
        user_id: participant.id,
        username: participant.username,
        emoji: "clap",
      )
      expect(messages.first.user_ids).to contain_exactly(participant.id, other_participant.id)
    end

    it "accepts the main reaction even when it isn't in the enabled list" do
      sign_in(participant)

      post "/live/rooms/#{room.id}/reaction.json",
           params: {
             emoji: "heart",
             participant_session_id: @session_id,
           }

      expect(response.status).to eq(204)
    end

    it "rejects an emoji outside the reaction set without broadcasting" do
      sign_in(participant)

      messages =
        MessageBus.track_publish(Live.room_channel(room.id)) do
          post "/live/rooms/#{room.id}/reaction.json",
               params: {
                 emoji: "poop",
                 participant_session_id: @session_id,
               }
        end

      expect(response.status).to eq(400)
      expect(messages).to be_empty
    end

    it "returns 400 for a non-string emoji when any emoji is allowed" do
      SiteSetting.discourse_reactions_allow_any_emoji = true
      sign_in(participant)

      post "/live/rooms/#{room.id}/reaction.json",
           params: {
             emoji: ["rocket"],
             participant_session_id: @session_id,
           }

      expect(response.status).to eq(400)
    end

    it "counts rejected emoji against the rate limit" do
      RateLimiter.enable
      sign_in(participant)

      Live::RoomsController::REACTIONS_PER_USER.times do
        post "/live/rooms/#{room.id}/reaction.json",
             params: {
               emoji: "poop",
               participant_session_id: @session_id,
             }
      end
      expect(response.status).to eq(400)

      post "/live/rooms/#{room.id}/reaction.json",
           params: {
             emoji: "poop",
             participant_session_id: @session_id,
           }

      expect(response.status).to eq(429)
    end

    it "returns 403 for a user who hasn't joined the call" do
      sign_in(outsider)

      post "/live/rooms/#{room.id}/reaction.json", params: { emoji: "clap" }

      expect(response.status).to eq(403)
    end

    it "rate limits bursts beyond the per-user budget" do
      RateLimiter.enable
      sign_in(participant)

      Live::RoomsController::REACTIONS_PER_USER.times do
        post "/live/rooms/#{room.id}/reaction.json",
             params: {
               emoji: "clap",
               participant_session_id: @session_id,
             }
      end
      expect(response.status).to eq(204)

      post "/live/rooms/#{room.id}/reaction.json",
           params: {
             emoji: "clap",
             participant_session_id: @session_id,
           }

      expect(response.status).to eq(429)
      # The picker stays disabled for exactly this long.
      expect(response.parsed_body.dig("extras", "wait_seconds")).to be_between(1, 10)
    end
  end
end
