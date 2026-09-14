# frozen_string_literal: true

require "rails_helper"

RSpec.describe Voice::AgentDispatcher do
  fab!(:user)
  fab!(:room) { Fabricate(:voice_room, public: true) }
  let(:bot) { Voice::AgentBot.user }

  before do
    SiteSetting.voice_enabled = true
    SiteSetting.voice_livekit_url = "wss://test.livekit.cloud"
    SiteSetting.voice_livekit_api_key = "key"
    SiteSetting.voice_livekit_api_secret = "secret"
    SiteSetting.voice_livekit_agent_enabled = true
    Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
    Voice::ParticipantTracker.add(room.id, user.id)
    @dispatch = nil
    stub_request(
      :post,
      "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/CreateDispatch",
    ).to_return do |request|
      @dispatch =
        JSON.parse(request.body).merge(
          "id" => "AD_test",
          "state" => {
            "jobs" => [
              {
                "dispatchId" => "AD_test",
                "state" => {
                  "status" => "JS_RUNNING",
                  "participantIdentity" => "agent-test",
                },
              },
            ],
          },
        )
      { status: 200, body: @dispatch.to_json }
    end
    stub_request(
      :post,
      "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/ListDispatch",
    ).to_return { { status: 200, body: { agentDispatches: [@dispatch].compact }.to_json } }
    @delete =
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/DeleteDispatch",
      ).to_return(status: 200, body: "{}")
    @update =
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.RoomService/UpdateParticipant",
      ).to_return(status: 200, body: "{}")
    stub_request(
      :post,
      "https://test.livekit.cloud/twirp/livekit.RoomService/RemoveParticipant",
    ).to_return(status: 200, body: "{}")
    stub_request(
      :post,
      "https://test.livekit.cloud/twirp/livekit.RoomService/DeleteRoom",
    ).to_return(status: 200, body: "{}")
    @participants = [{ identity: "agent-test", kind: "AGENT", sid: "PA_test" }]
    stub_request(
      :post,
      "https://test.livekit.cloud/twirp/livekit.RoomService/ListParticipants",
    ).to_return { { status: 200, body: { participants: @participants }.to_json } }
  end

  describe ".dispatch!" do
    it "maps the provider-attested job identity to the authorized bot and applies its permissions" do
      expect(described_class.dispatch!(room:, agent_name: "assistant")).to eq("AD_test")

      Voice::AgentManager.reconcile(room)

      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to eq([bot.id])
      expect(Voice::ParticipantTracker.get_metadata(room.id, bot.id)).to include(
        livekit_identity: "agent-test",
        external_agent: true,
        role: "speaker",
      )
      expect(
        @update.with(
          body:
            hash_including(
              "identity" => "agent-test",
              "permission" => hash_including("canPublish" => true, "canPublishData" => false),
            ),
        ),
      ).to have_been_requested
      expect(Voice::Session.where(user_id: bot.id)).to be_empty
    end

    it "rejects invitations to empty, mesh, and private rooms" do
      other_room = Fabricate(:voice_room, public: false)
      expect {
        described_class.dispatch!(room: other_room, agent_name: "assistant")
      }.to raise_error(Voice::AgentManager::AuthorizationError)
      Voice::ParticipantTracker.remove(room.id, user.id)
      expect { described_class.dispatch!(room:, agent_name: "assistant") }.to raise_error(
        Voice::AgentManager::AuthorizationError,
      )
      Voice::ParticipantTracker.add(room.id, user.id)
      Voice::ParticipantTracker.clear_transport_pin(room.id)
      Voice::ParticipantTracker.pin_transport!(room.id, "mesh")
      expect { described_class.dispatch!(room:, agent_name: "assistant") }.to raise_error(
        Voice::AgentManager::AuthorizationError,
      )
      Voice::ParticipantTracker.clear_transport_pin(room.id)
      Voice::ParticipantTracker.pin_transport!(room.id, "livekit")
      expect(@dispatch).to be_nil
    end

    it "rejects participant-supplied identity claims and unrelated dispatches" do
      described_class.dispatch!(room:, agent_name: "assistant")
      @participants = [{ identity: "impostor", kind: "AGENT", metadata: @dispatch["metadata"] }]
      Voice::AgentManager.reconcile(room)
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty

      @participants = [{ identity: "agent-test", kind: "AGENT" }]
      @dispatch["id"] = "AD_unrelated"
      Voice::AgentManager.reconcile(room)
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
    end

    it "requires an active agent job and an agent participant before admitting media" do
      described_class.dispatch!(room:, agent_name: "assistant")
      @dispatch["state"]["jobs"][0]["state"]["status"] = "JS_FAILED"
      Voice::AgentManager.reconcile(room)
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty

      @dispatch["state"]["jobs"][0]["state"]["status"] = "JS_RUNNING"
      @participants[0][:kind] = "STANDARD"
      Voice::AgentManager.reconcile(room)
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
    end

    it "withholds roster admission if provider permission enforcement fails" do
      described_class.dispatch!(room:, agent_name: "assistant")
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.RoomService/UpdateParticipant",
      ).to_return(status: 503)

      Voice::AgentManager.reconcile(room)

      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
    end

    it "rejects a snapshot revoked while provider permissions are being updated" do
      described_class.dispatch!(room:, agent_name: "assistant")
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.RoomService/UpdateParticipant",
      ).to_return do
        Voice::AgentManager.evict!(room:, user_id: bot.id)
        { status: 200, body: "{}" }
      end

      Voice::AgentManager.reconcile(room)

      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
      expect(
        a_request(
          :post,
          "https://test.livekit.cloud/twirp/livekit.RoomService/RemoveParticipant",
        ).with(body: hash_including("identity" => "agent-test")),
      ).to have_been_made.once
    end

    it "uses only the new dispatch when an invitation supersedes the previous job" do
      described_class.dispatch!(room:, agent_name: "assistant")
      previous = @dispatch
      described_class.dispatch!(room:, agent_name: "another-agent")
      expect(@dispatch["agent_name"]).to eq("another-agent")
      expect(@delete).to have_been_requested.once
      @dispatch = previous

      Voice::AgentManager.reconcile(room)

      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
    end

    it "deletes an in-flight dispatch if authorization is revoked during creation" do
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/CreateDispatch",
      ).to_return do
        Voice::AgentManager.evict!(room:, user_id: bot.id)
        { status: 200, body: { id: "AD_late" }.to_json }
      end

      expect { described_class.dispatch!(room:, agent_name: "assistant") }.to raise_error(
        Voice::AgentManager::AuthorizationError,
      )

      expect(@delete.with(body: hash_including("dispatch_id" => "AD_late"))).to have_been_requested
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
    end

    it "recovers and deletes a remotely created dispatch after its response times out" do
      stub_request(
        :post,
        "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/CreateDispatch",
      ).to_return do |request|
        @dispatch = JSON.parse(request.body).merge("id" => "AD_timeout")
        raise Net::ReadTimeout
      end
      expect { described_class.dispatch!(room:, agent_name: "assistant") }.to raise_error(
        described_class::DispatchError,
      )

      Voice::AgentManager.reconcile(room)

      expect(
        @delete.with(body: hash_including("dispatch_id" => "AD_timeout")),
      ).to have_been_requested
      expect(described_class.pending?(room.id)).to eq(false)
    end
  end

  describe ".cancel" do
    it "removes local admission immediately and retries failed dispatch deletion after a kick" do
      described_class.dispatch!(room:, agent_name: "assistant")
      Voice::AgentManager.reconcile(room)
      @delete =
        stub_request(
          :post,
          "https://test.livekit.cloud/twirp/livekit.AgentDispatchService/DeleteDispatch",
        ).to_return(status: 503).then.to_return(status: 200, body: "{}")

      Voice::AgentManager.evict!(room:, user_id: bot.id)

      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
      expect(described_class.pending?(room.id)).to eq(true)
      expect(
        a_request(
          :post,
          "https://test.livekit.cloud/twirp/livekit.RoomService/RemoveParticipant",
        ).with(body: hash_including("identity" => "agent-test")),
      ).to have_been_made.once
      Voice::AgentManager.reconcile(room)
      expect(described_class.pending?(room.id)).to eq(false)
      expect(@delete).to have_been_requested.twice
    end

    it "revokes active admission when the feature is disabled" do
      described_class.dispatch!(room:, agent_name: "assistant")
      Voice::AgentManager.reconcile(room)

      SiteSetting.voice_livekit_agent_enabled = false
      Voice::AgentManager.reconcile(room)

      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
      expect(@delete).to have_been_requested.once
    end

    it "stops the dispatch when the last human leaves" do
      described_class.dispatch!(room:, agent_name: "assistant")
      Voice::AgentManager.reconcile(room)
      Voice::ParticipantTracker.remove(room.id, user.id)

      Voice::AgentManager.evict_agents_in_room!(room)

      expect(@delete).to have_been_requested.once
      expect(described_class.pending?(room.id)).to eq(false)
      expect(Voice::ParticipantTracker.agent_user_ids(room.id)).to be_empty
    end
  end
end
