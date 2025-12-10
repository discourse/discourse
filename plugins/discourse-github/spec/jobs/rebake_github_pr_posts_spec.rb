# frozen_string_literal: true

RSpec.describe Jobs::RebakeGithubPrPosts do
  fab!(:user)
  fab!(:topic)
  let(:pr_url) { "https://github.com/discourse/discourse/pull/123" }
  let(:domain) { "github.com" }

  before { enable_current_plugin }

  def create_post_with_link(cooked)
    Fabricate(:post, topic:, user:, cooked:).tap do |post|
      TopicLink.create!(topic:, post:, user:, url: pr_url, domain:)
    end
  end

  describe "#execute" do
    it "does nothing with blank or missing pr_url" do
      expect { described_class.new.execute(pr_url: nil) }.not_to raise_error
      expect { described_class.new.execute(pr_url: "") }.not_to raise_error
    end

    it "rebakes posts with full GitHub PR oneboxes" do
      create_post_with_link(<<~HTML)
        <aside class="onebox githubpullrequest"><a href="#{pr_url}">PR</a></aside>
      HTML

      expect_any_instance_of(Post).to receive(:rebake!).with(
        invalidate_oneboxes: true,
        priority: :low,
      )

      described_class.new.execute(pr_url:)
    end

    it "does not rebake posts with plain links or inline oneboxes" do
      create_post_with_link(%(<a href="#{pr_url}">plain link</a>))
      create_post_with_link(%(<a href="#{pr_url}" class="inline-onebox">inline onebox</a>))

      expect_any_instance_of(Post).not_to receive(:rebake!)

      described_class.new.execute(pr_url:)
    end

    it "matches PR URLs with path suffixes like /files or /commits" do
      post = create_post_with_link(<<~HTML)
        <aside class="onebox githubpullrequest"><a href="#{pr_url}">PR</a></aside>
      HTML

      TopicLink.create!(topic:, post:, user:, url: "#{pr_url}/files", domain:)

      expect_any_instance_of(Post).to receive(:rebake!).with(
        invalidate_oneboxes: true,
        priority: :low,
      )

      described_class.new.execute(pr_url:)
    end

    context "with chat enabled" do
      fab!(:chat_channel)

      before do
        skip("Chat plugin not loaded") unless defined?(::Chat)
        SiteSetting.chat_enabled = true
      end

      def create_chat_message_with_link(cooked)
        Fabricate(:chat_message, chat_channel:, user:, cooked:).tap do |message|
          Chat::MessageLink.create!(chat_message: message, url: pr_url)
        end
      end

      it "rebakes chat messages with GitHub PR oneboxes and skips notifications" do
        create_chat_message_with_link(<<~HTML)
          <aside class="onebox githubpullrequest"><a href="#{pr_url}">PR</a></aside>
        HTML

        expect_any_instance_of(Chat::Message).to receive(:rebake!).with(
          invalidate_oneboxes: true,
          priority: :low,
          skip_notifications: true,
        )

        described_class.new.execute(pr_url:)
      end

      it "does not rebake chat messages without GitHub PR oneboxes" do
        create_chat_message_with_link(%(<a href="#{pr_url}">plain link</a>))

        expect_any_instance_of(Chat::Message).not_to receive(:rebake!)

        described_class.new.execute(pr_url:)
      end
    end
  end
end
