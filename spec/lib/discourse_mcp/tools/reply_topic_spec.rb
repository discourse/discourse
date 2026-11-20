# frozen_string_literal: true

RSpec.describe DiscourseMcp::Tools::ReplyTopic do
  describe ".call" do
    subject(:created_post) do
      described_class.call(arguments:, request_context:).fetch(:structuredContent)
    end

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:moderator)
    fab!(:category)
    fab!(:topic) { Fabricate(:topic, category:) }
    fab!(:first_post) { Fabricate(:post, topic:) }

    let(:arguments) do
      {
        "topic_id" => topic.id,
        "raw" => "A complete reply body for this example.",
        "reply_to_post_number" => first_post.post_number,
      }
    end
    let(:request_context) { DiscourseMcp::RequestContext.new(access_token) }
    let(:access_token) do
      McpOauthAccessToken.new(authorization: McpOauthAuthorization.new(user:), user:, scopes:)
    end
    let(:scopes) { [DiscourseMcp::Scopes::CONTENT_WRITE] }
    let(:output_schema) do
      JSONSchemer.schema(DiscourseMcp.registry.find(:tool, "discourse_create_post").output_schema)
    end
    let(:queued_reply) { ReviewableQueuedPost.find_by(target_created_by: user) }

    context "when the reply is too short" do
      let(:arguments) { super().merge("raw" => "x") }

      it "raises a tool error" do
        expect { created_post }.to raise_error(DiscourseMcp::ToolError, /Body is too short/)
      end
    end

    context "when the user is silenced" do
      before { user.update!(silenced_till: 1.year.from_now) }

      it "raises a tool error" do
        expect { created_post }.to raise_error(DiscourseMcp::ToolError, I18n.t("topic_not_found"))
      end
    end

    context "when a watched word requires approval" do
      before do
        Fabricate(:watched_word, word: "complete", action: WatchedWord.actions[:require_approval])
      end

      context "when a moderator approves the queued reply" do
        subject(:approved_reply) { queued_reply.perform(moderator, :approve_post).created_post }

        before { created_post }

        it "publishes the reply as the user submitted it" do
          expect(approved_reply).to have_attributes(
            topic:,
            user:,
            raw: arguments["raw"],
            reply_to_post_number: first_post.post_number,
          )
        end
      end

      context "when the topic is a private message" do
        fab!(:topic) { Fabricate(:private_message_topic, user:) }
        fab!(:first_post) { Fabricate(:post, topic:, user:) }

        let(:scopes) { super() + [DiscourseMcp::Scopes::PRIVATE_MESSAGES_WRITE] }

        it "publishes the reply" do
          expect(created_post).to include(queued: false)
        end
      end

      it "returns the queued state" do
        expect(created_post).to include(queued: true, id: nil, topic_id: topic.id, post_number: nil)
      end

      it "returns a result that matches the output schema" do
        expect(output_schema).to be_valid(created_post.as_json)
      end

      it "publishes no reply" do
        expect { created_post }.not_to change { topic.posts.count }
      end
    end

    context "when the category requires approval of replies" do
      before { category.update!(category_setting_attributes: { require_reply_approval: true }) }

      context "when the reply is too short" do
        let(:arguments) { super().merge("raw" => "x") }

        it "raises a tool error" do
          expect { created_post }.to raise_error(DiscourseMcp::ToolError, /\Ais too short/)
        end
      end

      it "returns the queued state" do
        expect(created_post).to include(queued: true)
      end
    end

    context "when no rule requires approval" do
      it "returns the published reply" do
        expect(created_post).to include(
          queued: false,
          id: topic.posts.last.id,
          topic_id: topic.id,
          post_number: 2,
          username: user.username,
        )
      end

      it "returns a result that matches the output schema" do
        expect(output_schema).to be_valid(created_post.as_json)
      end
    end
  end
end
