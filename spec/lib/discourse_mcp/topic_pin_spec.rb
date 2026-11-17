# frozen_string_literal: true

describe DiscourseMcp::Tools::SetTopicPin do
  fab!(:admin)
  fab!(:user)
  fab!(:topic)

  def invoke(mode, actor: admin, target: topic, scopes: [])
    authorization = McpOauthAuthorization.new(user: actor)
    token = McpOauthAccessToken.new(authorization: authorization, user: actor, scopes: scopes)
    described_class.call(
      arguments: {
        "topic_id" => target.id,
        "mode" => mode,
      },
      request_context: DiscourseMcp::RequestContext.new(token),
    )
  end

  describe ".call" do
    it "pins within a category, switches to global and unpins with persisted receipts" do
      expect(invoke("category")[:structuredContent]).to include(
        pinned: true,
        pinned_globally: false,
      )
      expect(topic.reload.pinned_at).to be_present
      expect(invoke("global")[:structuredContent]).to include(pinned: true, pinned_globally: true)
      expect(topic.reload.pinned_globally).to eq(true)
      expect(invoke("unpin")[:structuredContent]).to include(
        pinned: false,
        pinned_globally: false,
        pinned_until: nil,
      )
      expect(topic.reload.pinned_at).to be_nil
    end

    it "denies users without pin permissions" do
      expect { invoke("category", actor: user) }.to raise_error(Discourse::InvalidAccess)
      expect(topic.reload.pinned_at).to be_nil
    end

    it "allows category moderators to pin locally but not globally" do
      SiteSetting.enable_category_group_moderation = true
      user.update!(trust_level: TrustLevel[1])
      group = Fabricate(:group)
      group.add(user)
      Fabricate(:category_moderation_group, category: topic.category, group:)

      expect { invoke("global", actor: user) }.to raise_error(Discourse::InvalidAccess)
      expect(topic.reload.pinned_at).to be_nil
      expect(topic.pinned_globally).to eq(false)
      expect(invoke("category", actor: user)[:structuredContent]).to include(
        pinned: true,
        pinned_globally: false,
      )
      expect(invoke("unpin", actor: user)[:structuredContent]).to include(pinned: false)
    end

    it "allows global pins for trust level four users under normal moderation permissions" do
      user.update!(trust_level: TrustLevel[4])

      expect(invoke("global", actor: user)[:structuredContent]).to include(
        pinned: true,
        pinned_globally: true,
      )
    end

    it "denies global pins for silenced trust level four users" do
      user.update!(trust_level: TrustLevel[4], silenced_till: 1.day.from_now)

      expect { invoke("global", actor: user) }.to raise_error(Discourse::InvalidAccess)
      expect(topic.reload.pinned_at).to be_nil
      expect(topic.pinned_globally).to eq(false)
    end

    it "replaces an existing pin expiration" do
      topic.update!(pinned_at: 1.day.ago, pinned_until: 1.day.from_now)

      expect(invoke("global")[:structuredContent]).to include(
        pinned: true,
        pinned_globally: true,
        pinned_until: nil,
      )
      expect(topic.reload.pinned_until).to be_nil
    end

    it "requires private message write scope for private topics" do
      private_topic = Fabricate(:private_message_topic)

      expect { invoke("category", target: private_topic) }.to raise_error(DiscourseMcp::Error)
      expect(private_topic.reload.pinned_at).to be_nil
      expect(
        invoke(
          "category",
          target: private_topic,
          scopes: [DiscourseMcp::Scopes::PRIVATE_MESSAGES_WRITE],
        )[
          :structuredContent
        ],
      ).to include(pinned: true)
    end

    it "rejects invalid modes without mutating the topic" do
      expect { invoke("bogus") }.to raise_error(Discourse::InvalidParameters)
      expect(topic.reload.pinned_at).to be_nil
    end

    it "hides inaccessible topics" do
      private_topic = Fabricate(:private_message_topic)
      expect { invoke("category", actor: user, target: private_topic) }.to raise_error(
        DiscourseMcp::ToolError,
      )
      expect(private_topic.reload.pinned_at).to be_nil
    end
  end
end
