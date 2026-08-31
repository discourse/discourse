# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::RoomsController do
  fab!(:flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:flagged_user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:room) { Fabricate(:voice_room, public: true) }

  fab!(:session) { Fabricate(:voice_session, room: room, user: flagged_user, left_at: nil) }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_allowed_groups = Group::AUTO_GROUPS[:everyone]
    Group.refresh_automatic_groups!
  end

  describe "#flag" do
    let(:params) do
      {
        user_id: flagged_user.id,
        flag_type_id: ReviewableScore.types[:notify_moderators],
        message: "This participant is being disruptive on the call.",
      }
    end

    it "requires the user to be logged in" do
      post "/voice/rooms/#{room.id}/flag.json", params: params

      expect(response.status).to eq(403)
    end

    it "creates a reviewable targeting the user's session and a companion PM to moderators" do
      sign_in(flagger)

      expect { post "/voice/rooms/#{room.id}/flag.json", params: params }.to change {
        ReviewableVoiceUser.count
      }.by(1).and change { Topic.private_messages.count }.by(1)

      expect(response.status).to eq(200)

      reviewable = ReviewableVoiceUser.last
      expect(reviewable.target).to eq(session)
      expect(reviewable.target_created_by).to eq(flagged_user)
      expect(reviewable.created_by).to eq(flagger)
      expect(reviewable.payload["message"]).to eq(params[:message])
      expect(reviewable.payload["room_id"]).to eq(room.id)

      pm = Topic.private_messages.last
      expect(pm.subtype).to eq(TopicSubtype.notify_moderators)
      expect(pm.first_post.raw).to include(params[:message])
      expect(reviewable.reviewable_scores.first.meta_topic_id).to eq(pm.id)
    end

    it "rejects flag types other than notify_moderators" do
      sign_in(flagger)

      post "/voice/rooms/#{room.id}/flag.json",
           params: params.merge(flag_type_id: ReviewableScore.types[:spam])

      expect(response.status).to eq(400)
      expect(ReviewableVoiceUser.count).to eq(0)
    end

    it "rejects a flag without a message" do
      sign_in(flagger)

      post "/voice/rooms/#{room.id}/flag.json", params: params.merge(message: "")

      expect(response.status).to eq(400)
      expect(ReviewableVoiceUser.count).to eq(0)
    end

    it "rejects flagging yourself" do
      sign_in(flagger)

      post "/voice/rooms/#{room.id}/flag.json", params: params.merge(user_id: flagger.id)

      expect(response.status).to eq(403)
    end

    it "rejects flagging a user who never joined the room" do
      other_room = Fabricate(:voice_room, public: true)
      sign_in(flagger)

      post "/voice/rooms/#{other_room.id}/flag.json", params: params

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("voice.errors.flag_target_never_joined"),
      )
    end

    it "rejects a second flag while the flagger already has a pending one" do
      sign_in(flagger)

      post "/voice/rooms/#{room.id}/flag.json", params: params
      expect(response.status).to eq(200)

      post "/voice/rooms/#{room.id}/flag.json", params: params

      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(I18n.t("voice.errors.flag_already_handled"))
      expect(ReviewableVoiceUser.count).to eq(1)
    end

    it "lets another user add a score to the existing reviewable" do
      other_flagger = Fabricate(:user, trust_level: TrustLevel[2])
      sign_in(flagger)
      post "/voice/rooms/#{room.id}/flag.json", params: params

      sign_in(other_flagger)
      post "/voice/rooms/#{room.id}/flag.json", params: params

      expect(response.status).to eq(200)
      expect(ReviewableVoiceUser.count).to eq(1)
      expect(ReviewableVoiceUser.last.reviewable_scores.map(&:user_id)).to contain_exactly(
        flagger.id,
        other_flagger.id,
      )
    end

    it "rejects flagging in a private room the flagger cannot join" do
      private_room = Fabricate(:voice_room, public: false)
      Fabricate(:voice_session, room: private_room, user: flagged_user, left_at: nil)
      sign_in(flagger)

      post "/voice/rooms/#{private_room.id}/flag.json", params: params

      expect(response.status).to eq(403)
      expect(ReviewableVoiceUser.count).to eq(0)
    end
  end
end
