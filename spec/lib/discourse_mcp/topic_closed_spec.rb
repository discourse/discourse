# frozen_string_literal: true

RSpec.describe DiscourseMcp::Tools::SetTopicClosed do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:topic) { Fabricate(:topic, featured_link: "https://example.com/reference") }

  def invoke(closed, actor: admin, topic_id: topic.id, scopes: [])
    authorization = McpOauthAuthorization.new(user: actor)
    token = McpOauthAccessToken.new(authorization: authorization, user: actor, scopes: scopes)
    described_class.call(
      arguments: {
        "topic_id" => topic_id,
        "closed" => closed,
      },
      request_context: DiscourseMcp::RequestContext.new(token),
    )
  end

  describe ".call" do
    it "registers a strict boolean schema with moderation access and risk" do
      primitive = DiscourseMcp.registry.find(:tool, "discourse_set_topic_closed")
      expect(primitive.required_scopes).to eq([DiscourseMcp::Scopes::MODERATION_WRITE])
      expect(primitive.risk).to eq(:moderation)
      expect(primitive.input_schema).to include(
        "required" => %w[topic_id closed],
        "additionalProperties" => false,
      )
      expect(primitive.input_schema.dig("properties", "closed")).to eq("type" => "boolean")
    end

    it "closes and reopens with persisted receipts, action posts, and staff attribution" do
      expect(invoke(true, actor: moderator)[:structuredContent]).to eq(
        topic_id: topic.id,
        closed: true,
        archived: false,
      )
      expect(topic.reload.closed).to eq(true)
      expect(invoke(false, actor: moderator)[:structuredContent]).to eq(
        topic_id: topic.id,
        closed: false,
        archived: false,
      )
      expect(topic.reload.closed).to eq(false)
      expect(topic.featured_link).to eq("https://example.com/reference")
      expect(topic.posts.where(user: moderator).order(:id).pluck(:action_code)).to eq(
        %w[closed.enabled closed.disabled],
      )
      expect(
        UserHistory
          .where(acting_user_id: moderator.id, topic_id: topic.id)
          .order(:id)
          .pluck(:action),
      ).to eq([UserHistory.actions[:topic_closed], UserHistory.actions[:topic_opened]])
    end

    it "allows the same topic moderation permissions as the UI" do
      leader = Fabricate(:user, trust_level: TrustLevel[4])
      expect(invoke(true, actor: leader)[:structuredContent]).to include(closed: true)
      expect { invoke(false, actor: user) }.to raise_error(Discourse::InvalidAccess)
      expect(topic.reload.closed).to eq(true)
    end

    it "hides missing and inaccessible topics" do
      private_topic = Fabricate(:private_message_topic)
      [0, private_topic.id].each do |topic_id|
        expect { invoke(true, actor: user, topic_id: topic_id) }.to raise_error(
          DiscourseMcp::ToolError,
        )
      end
      expect(private_topic.reload.closed).to eq(false)
    end

    it "requires private message write scope for private topics" do
      private_topic = Fabricate(:private_message_topic)
      expect { invoke(true, topic_id: private_topic.id) }.to raise_error(DiscourseMcp::Error)
      expect(
        invoke(
          true,
          topic_id: private_topic.id,
          scopes: [DiscourseMcp::Scopes::PRIVATE_MESSAGES_WRITE],
        )[
          :structuredContent
        ],
      ).to include(closed: true)
    end

    it "rejects invalid closed values without changing the topic" do
      [nil, "false", 0].each do |closed|
        expect { invoke(closed) }.to raise_error(Discourse::InvalidParameters)
      end
      expect(topic.reload.closed).to eq(false)
    end

    it "retains archived state and avoids duplicate status posts, audit records, and events on retries" do
      topic.update!(closed: true, archived: true)
      events =
        DiscourseEvent.track_events(:topic_closed) do
          [false, true].each do |closed|
            2.times do
              expect(invoke(closed)[:structuredContent]).to include(closed: closed, archived: true)
            end
          end
        end
      expect(topic.posts.where(action_code: "closed.disabled").count).to eq(1)
      expect(topic.posts.where(action_code: "closed.enabled").count).to eq(1)
      expect(
        UserHistory.where(acting_user_id: admin.id, topic_id: topic.id).order(:id).pluck(:action),
      ).to eq([UserHistory.actions[:topic_opened], UserHistory.actions[:topic_closed]])
      expect(events.size).to eq(1)
    end
  end
end
