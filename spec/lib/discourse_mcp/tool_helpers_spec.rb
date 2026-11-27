# frozen_string_literal: true

describe DiscourseMcp::ToolHelpers do
  describe ".topic_plugin_data" do
    it "adds namespaced plugin data to topic reads and filters using the current request context" do
      topic = Fabricate(:post).topic
      user = Fabricate(:user)
      context = Struct.new(:user, :guardian).new(user, Guardian.new(user))
      plugin = Plugin::Instance.new
      modifier =
        lambda do |data, topics, request_context|
          expect(topics).to eq([topic])
          expect(request_context).to eq(context)
          data.merge(topic.id => { "example" => { "visible" => true } })
        end
      plugin.register_modifier(:mcp_topic_plugin_data, &modifier)

      read =
        DiscourseMcp::Tools::GetTopic.call(
          arguments: {
            "topic_id" => topic.id,
          },
          request_context: context,
        ).fetch(:structuredContent)
      filtered =
        DiscourseMcp::Tools::FilterTopics
          .call(arguments: { "view" => "filtered", "filter" => "in:all" }, request_context: context)
          .fetch(:structuredContent)
          .fetch(:results)
          .first
      [read, filtered].each do |result|
        expect(result[:plugin_data]).to eq("example" => { "visible" => true })
      end
      expect(
        JSONSchemer.schema(DiscourseMcp::Tools::GetTopic::OUTPUT_SCHEMA).valid?(
          JSON.parse(JSON.generate(read)),
        ),
      ).to eq(true)
    ensure
      DiscoursePluginRegistry.unregister_modifier(plugin, :mcp_topic_plugin_data, &modifier)
    end
  end

  describe ".submit_post!" do
    subject(:submission) { described_class.submit_post!(user, title:, raw:) }

    fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }

    let(:title) { "A topic submitted through the helper" }
    let(:raw) { "A complete topic body for this example." }

    context "when a handler takes the post" do
      before { allow(NewPostManager).to receive(:handlers).and_return([handler]) }

      context "when the handler returns a failed result without errors" do
        let(:handler) { ->(_manager) { NewPostResult.new(:custom) } }

        it "raises a tool error with a default message" do
          expect { submission }.to raise_error(
            DiscourseMcp::ToolError,
            I18n.t("mcp.errors.post_not_created"),
          )
        end
      end

      context "when the handler returns a successful result without a post" do
        let(:handler) { ->(_manager) { NewPostResult.new(:custom, true) } }

        it "raises a tool error with a default message" do
          expect { submission }.to raise_error(
            DiscourseMcp::ToolError,
            I18n.t("mcp.errors.post_not_created"),
          )
        end
      end

      context "when the handler queues the post" do
        let(:handler) { ->(manager) { manager.enqueue(:custom) } }

        it "returns the queued submission" do
          expect(submission).to have_attributes(action: :enqueued, post: nil)
        end
      end
    end

    context "when no handler takes the post" do
      it "returns the published post" do
        expect(submission.post).to have_attributes(user:, raw:)
      end
    end
  end
end
