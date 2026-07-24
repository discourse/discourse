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
    def seed_onebox_caches(url)
      Discourse.cache.write(
        Oneboxer.send(:onebox_cache_key, url),
        { onebox: "stale", preview: "stale" },
      )
      Discourse.cache.write(InlineOneboxer.send(:cache_key, url), { url:, title: "stale" })
    end

    it "does nothing for a blank, malformed, or non-PR pr_url" do
      create_post_with_link(<<~HTML)
        <aside class="onebox githubpullrequest"><a href="#{pr_url}">PR</a></aside>
      HTML
      seed_onebox_caches(pr_url)

      expect_any_instance_of(Post).not_to receive(:rebake!)
      bad_urls = [
        "",
        nil,
        "https:// bad",
        "https://github.com",
        "#{pr_url}/../../456",
        "mailto:x@y.com",
      ]
      bad_urls.each { |bad| expect { described_class.new.execute(pr_url: bad) }.not_to raise_error }

      expect(Oneboxer.cached_onebox(pr_url)).to eq("stale")
    end

    it "clears the onebox caches for the exact PR URL variant a post used (e.g. /changes)" do
      variant = "#{pr_url}/changes"
      post = Fabricate(:post, topic:, user:, cooked: <<~HTML)
        <aside class="onebox githubpullrequest"><a href="#{variant}">PR</a></aside>
      HTML
      TopicLink.create!(topic:, post:, user:, url: variant, domain:)
      seed_onebox_caches(variant)
      allow_any_instance_of(Post).to receive(:rebake!)

      described_class.new.execute(pr_url:)

      expect(Oneboxer.cached_onebox(variant)).to be_blank
      expect(InlineOneboxer.cache_lookup(variant)).to be_blank
    end

    it "refreshes links using scheme and host variants (http, www)" do
      www_url = pr_url.sub("https://", "https://www.")
      http_url = pr_url.sub("https://", "http://")
      post = Fabricate(:post, topic:, user:, cooked: <<~HTML)
        <aside class="onebox githubpullrequest"><a href="#{www_url}">PR</a></aside>
      HTML
      TopicLink.create!(topic:, post:, user:, url: www_url, domain: "www.github.com")
      TopicLink.create!(topic:, post:, user:, url: http_url, domain:)
      seed_onebox_caches(www_url)
      seed_onebox_caches(http_url)

      expect_any_instance_of(Post).to receive(:rebake!)
      described_class.new.execute(pr_url:)

      expect(Oneboxer.cached_onebox(www_url)).to be_blank
      expect(Oneboxer.cached_onebox(http_url)).to be_blank
    end

    it "clears the normalized-encoding cache key used by full oneboxes" do
      raw = "#{pr_url}#r\u00e9view"
      normalized = UrlHelper.normalized_encode(raw).to_s
      post = Fabricate(:post, topic:, user:, cooked: <<~HTML)
        <aside class="onebox githubpullrequest"><a href="#{raw}">PR</a></aside>
      HTML
      TopicLink.create!(topic:, post:, user:, url: raw, domain:)
      Discourse.cache.write(
        Oneboxer.send(:onebox_cache_key, normalized),
        { onebox: "stale", preview: "stale" },
      )
      allow_any_instance_of(Post).to receive(:rebake!)

      described_class.new.execute(pr_url:)

      expect(normalized).not_to eq(raw)
      expect(Oneboxer.cached_onebox(normalized)).to be_blank
    end

    it "leaves a different PR that only shares a number prefix untouched" do
      other_pr = "#{pr_url}4" # ...pull/123 must not match ...pull/1234
      post = Fabricate(:post, topic:, user:, cooked: <<~HTML)
        <aside class="onebox githubpullrequest"><a href="#{other_pr}">PR</a></aside>
      HTML
      TopicLink.create!(topic:, post:, user:, url: other_pr, domain:)
      seed_onebox_caches(other_pr)

      expect_any_instance_of(Post).not_to receive(:rebake!)
      described_class.new.execute(pr_url:)

      expect(Oneboxer.cached_onebox(other_pr)).to eq("stale")
    end

    it "rebakes posts with full GitHub PR oneboxes" do
      create_post_with_link(<<~HTML)
        <aside class="onebox githubpullrequest"><a href="#{pr_url}">PR</a></aside>
      HTML
      expect_any_instance_of(Post).to receive(:rebake!).with(
        priority: :low,
        skip_publish_rebaked_changes: true,
      )

      described_class.new.execute(pr_url:)
    end

    it "rebakes posts with inline oneboxes for the PR URL" do
      create_post_with_link(%(<a href="#{pr_url}" class="inline-onebox">inline onebox</a>))
      expect_any_instance_of(Post).to receive(:rebake!).with(
        priority: :low,
        skip_publish_rebaked_changes: true,
      )

      described_class.new.execute(pr_url:)
    end

    it "does not rebake posts with plain links" do
      create_post_with_link(%(<a href="#{pr_url}">plain link</a>))
      expect_any_instance_of(Post).not_to receive(:rebake!)

      described_class.new.execute(pr_url:)
    end

    it "does not rebake posts with an inline onebox for an unrelated URL" do
      create_post_with_link(%(<a href="https://example.com/other" class="inline-onebox">other</a>))
      expect_any_instance_of(Post).not_to receive(:rebake!)

      described_class.new.execute(pr_url:)
    end

    it "matches PR URLs with path suffixes like /files or /commits" do
      post = create_post_with_link(<<~HTML)
        <aside class="onebox githubpullrequest"><a href="#{pr_url}">PR</a></aside>
      HTML

      TopicLink.create!(topic:, post:, user:, url: "#{pr_url}/files", domain:)

      expect_any_instance_of(Post).to receive(:rebake!).with(
        priority: :low,
        skip_publish_rebaked_changes: true,
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

      it "rebakes chat messages with inline oneboxes for the PR URL" do
        create_chat_message_with_link(%(<a href="#{pr_url}" class="inline-onebox">inline</a>))

        expect_any_instance_of(Chat::Message).to receive(:rebake!).with(
          priority: :low,
          skip_notifications: true,
        )

        described_class.new.execute(pr_url:)
      end

      it "clears the onebox caches for the exact PR URL variant a chat message used" do
        variant = "#{pr_url}/files"
        message = Fabricate(:chat_message, chat_channel:, user:, cooked: <<~HTML)
          <aside class="onebox githubpullrequest"><a href="#{variant}">PR</a></aside>
        HTML
        Chat::MessageLink.create!(chat_message: message, url: variant)
        seed_onebox_caches(variant)
        allow_any_instance_of(Chat::Message).to receive(:rebake!)

        described_class.new.execute(pr_url:)

        expect(Oneboxer.cached_onebox(variant)).to be_blank
        expect(InlineOneboxer.cache_lookup(variant)).to be_blank
      end
    end
  end
end
