# frozen_string_literal: true

RSpec.describe DiscourseMcp::Tools::CreateTopic do
  describe ".call" do
    subject(:created_topic) do
      described_class.call(arguments:, request_context:).fetch(:structuredContent)
    end

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:moderator)
    fab!(:category)
    fab!(:tag)

    let(:arguments) do
      {
        "title" => "A topic made through an MCP tool",
        "raw" => "A complete topic body for this example.",
        "category_id" => category.id,
        "tags" => [tag.name],
      }
    end
    let(:request_context) { DiscourseMcp::RequestContext.new(access_token) }
    let(:access_token) do
      McpOauthAccessToken.new(
        authorization: McpOauthAuthorization.new(user:),
        user:,
        scopes: [DiscourseMcp::Scopes::CONTENT_WRITE],
      )
    end
    let(:output_schema) do
      JSONSchemer.schema(DiscourseMcp.registry.find(:tool, "discourse_create_topic").output_schema)
    end
    let(:queued_topic) { ReviewableQueuedPost.find_by(target_created_by: user) }

    context "when the title is too short" do
      let(:arguments) { super().merge("title" => "x") }

      it "raises a tool error" do
        expect { created_topic }.to raise_error(DiscourseMcp::ToolError, /Title/)
      end
    end

    context "when the category does not exist" do
      let(:arguments) { super().merge("category_id" => -1) }

      it "rejects the parameters" do
        expect { created_topic }.to raise_error(Discourse::InvalidParameters)
      end
    end

    context "when the user is silenced" do
      before { user.update!(silenced_till: 1.year.from_now) }

      context "when the category does not exist" do
        let(:arguments) { super().merge("category_id" => -1) }

        it "denies access" do
          expect { created_topic }.to raise_error(Discourse::InvalidAccess)
        end
      end

      it "denies access" do
        expect { created_topic }.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "when a watched word requires approval" do
      before do
        Fabricate(:watched_word, word: "complete", action: WatchedWord.actions[:require_approval])
      end

      context "when a moderator approves the queued topic" do
        subject(:approved_topic) do
          queued_topic.perform(moderator, :approve_post).created_post.topic
        end

        before { created_topic }

        it "publishes the topic as the user submitted it" do
          expect(approved_topic).to have_attributes(
            title: arguments["title"],
            user:,
            category:,
            tags: [tag],
            first_post: have_attributes(raw: arguments["raw"]),
          )
        end
      end

      context "when the user is a staff member" do
        fab!(:user, :moderator)

        it "publishes the topic" do
          expect(created_topic).to include(queued: false)
        end
      end

      it "returns the queued state" do
        expect(created_topic).to include(
          queued: true,
          id: nil,
          topic_id: nil,
          slug: nil,
          title: arguments["title"],
        )
      end

      it "returns a result that matches the output schema" do
        expect(output_schema).to be_valid(created_topic.as_json)
      end

      it "publishes no topic" do
        expect { created_topic }.not_to change { Topic.count }
      end

      it "queues the topic for review" do
        expect { created_topic }.to change {
          ReviewableQueuedPost.where(target_created_by: user).count
        }.by(1)
      end
    end

    context "when the category requires approval of new topics" do
      before { category.update!(category_setting_attributes: { require_topic_approval: true }) }

      it "returns the queued state" do
        expect(created_topic).to include(queued: true)
      end
    end

    context "when the user is below the approved post count" do
      fab!(:user) { Fabricate(:user, refresh_auto_groups: true, trust_level: TrustLevel[0]) }

      before { SiteSetting.approve_post_count = 5 }

      it "returns the queued state" do
        expect(created_topic).to include(queued: true)
      end
    end

    context "when the user is outside the groups that skip approval" do
      before { SiteSetting.approve_unless_allowed_groups = Group::AUTO_GROUPS[:trust_level_4].to_s }

      it "returns the queued state" do
        expect(created_topic).to include(queued: true)
      end
    end

    context "when the user is outside the groups that skip approval of new topics" do
      before do
        SiteSetting.approve_new_topics_unless_allowed_groups =
          Group::AUTO_GROUPS[:trust_level_4].to_s
      end

      it "returns the queued state" do
        expect(created_topic).to include(queued: true)
      end
    end

    context "when the topic is the first post of a new user" do
      fab!(:user) { Fabricate(:user, refresh_auto_groups: true, trust_level: TrustLevel[0]) }

      it "publishes the topic" do
        expect(created_topic).to include(queued: false)
      end

      it "leaves the user unsilenced" do
        expect { created_topic }.not_to change { user.reload.silenced? }.from(false)
      end
    end

    context "when the request names the user as the author" do
      let(:arguments) { super().merge("author_username" => user.username.upcase) }

      it "returns the requested author as applied" do
        expect(created_topic).to include(
          username: user.username,
          requested_author: arguments["author_username"],
          author_applied: true,
        )
      end
    end

    context "when no rule requires approval" do
      it "returns the published topic" do
        expect(created_topic).to include(
          queued: false,
          topic_id: Topic.find_by(user:).id,
          title: arguments["title"],
          username: user.username,
        )
      end

      it "returns a result that matches the output schema" do
        expect(output_schema).to be_valid(created_topic.as_json)
      end
    end
  end
end
