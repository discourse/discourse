# frozen_string_literal: true

RSpec.describe SharedAiConversation, type: :model do
  fab!(:claude_2) { Fabricate(:llm_model, name: "claude-2") }

  before do
    enable_current_plugin
    SiteSetting.ai_bot_enabled = true
    toggle_enabled_bots(bots: [claude_2])
  end

  fab!(:user)

  let(:bad_user_input) { <<~HTML }
    Just trying something `<marquee style="font-size: 200px; color: red;" scrollamount=20>h4cked</marquee>`
  HTML
  let(:raw_with_details) { <<~HTML }
    <details>
    <summary>GitHub pull request diff</summary>
    <p><a href="https://github.com/discourse/discourse-ai/pull/521">discourse/discourse-ai 521</a></p>
    </details>
    <p>This is some other text</p>
  HTML

  let(:bot_user) { claude_2.reload.user }
  let!(:topic) { Fabricate(:private_message_topic, recipient: bot_user) }
  let!(:post1) { Fabricate(:post, topic: topic, post_number: 1, raw: bad_user_input) }
  let!(:post2) { Fabricate(:post, topic: topic, post_number: 2, raw: raw_with_details) }

  describe ".share_conversation" do
    it "creates a new conversation if one does not exist" do
      expect { described_class.share_conversation(user, topic) }.to change {
        described_class.count
      }.by(1)
    end

    it "generates a good onebox" do
      conversation = described_class.share_conversation(user, topic)
      onebox = conversation.onebox
      expect(onebox).not_to include("GitHub pull request diff")
      expect(onebox).not_to include("<details>")

      expect(onebox).to include("AI Conversation with Claude-2")
    end

    it "updates an existing conversation if one exists" do
      conversation = described_class.share_conversation(user, topic)
      expect(conversation.share_key).to be_present

      topic.update!(title: "New title")

      expect { described_class.share_conversation(user, topic) }.to_not change {
        described_class.count
      }
      expect(conversation.reload.title).to eq("New title")
      expect(conversation.share_key).to be_present
    end

    it "includes the correct conversation data" do
      conversation = described_class.share_conversation(user, topic)
      expect(conversation.llm_name).to eq("Claude-2")
      expect(conversation.title).to eq(topic.title)
      expect(conversation.context.size).to eq(2)
      expect(conversation.context[0]["id"]).to eq(post1.id)
      expect(conversation.context[1]["id"]).to eq(post2.id)

      populated_context = conversation.populated_context

      expect(populated_context[0].id).to eq(post1.id)
      expect(populated_context[0].user.id).to eq(post1.user.id)
      expect(populated_context[1].id).to eq(post2.id)
      expect(populated_context[1].user.id).to eq(post2.user.id)
    end

    it "shares artifacts publicly when conversation is shared" do
      # Create a post with an AI artifact
      artifact =
        Fabricate(
          :ai_artifact,
          post: post1,
          user: user,
          metadata: {
            public: false,
            something: "good",
          },
        )

      _post_with_artifact =
        Fabricate(
          :post,
          topic: topic,
          post_number: 3,
          raw: "Here's an artifact",
          cooked:
            "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}' data-ai-artifact-version='1'></div>",
        )

      expect(artifact.public?).to be_falsey

      conversation = described_class.share_conversation(user, topic)
      artifact.reload

      expect(artifact.metadata["something"]).to eq("good")
      expect(artifact.public?).to be_truthy

      described_class.destroy_conversation(conversation)
      artifact.reload

      expect(artifact.metadata["something"]).to eq("good")
      expect(artifact.public?).to be_falsey
    end

    it "does not share artifacts publicly when refreshing the share fails" do
      SiteSetting.ai_artifact_security = "lax"

      conversation = described_class.share_conversation(user, topic)
      conversation.update_column(:share_key, "")

      artifact =
        Fabricate(
          :ai_artifact,
          post: post1,
          user: user,
          metadata: {
            public: false,
            something: "good",
          },
        )

      Fabricate(
        :post,
        topic: topic,
        post_number: 3,
        raw: "Here's an artifact",
        cooked: "<div class='ai-artifact' data-ai-artifact-id='#{artifact.id}'></div>",
      )

      described_class.share_conversation(user, topic)

      expect(artifact.reload.metadata["something"]).to eq("good")
      expect(artifact.public?).to be_falsey
    end

    it "escapes HTML" do
      conversation = described_class.share_conversation(user, topic)
      onebox = conversation.onebox
      expect(onebox).not_to include("</marquee>")
      expect(onebox).to include("AI Conversation with Claude-2")
    end

    it "escapes HTML in the title to prevent XSS" do
      conversation = described_class.share_conversation(user, topic)
      xss_title = "<img src=x onerror=alert(1)>"
      conversation.update!(title: xss_title)
      onebox = conversation.onebox

      expect(onebox).not_to include(xss_title)
      expect(onebox).to include(ERB::Util.html_escape(xss_title))
    end
  end

  describe "#onebox" do
    it "renders punctuation and Unicode as text while preserving the onebox structure" do
      conversation = described_class.share_conversation(user, topic)
      conversation.update!(title: %(A < B & "東京"), llm_name: "Research & <édition>")
      conversation.share_key = %(review "A&B")
      read_more = "Continue & <次へ>"
      TranslationOverride.upsert!(I18n.locale, "discourse_ai.share_ai.read_more", read_more)

      onebox = Nokogiri::HTML5.fragment(conversation.onebox)

      expect(onebox.css("div > aside.onebox.allowlistedgeneric").size).to eq(1)
      expect(onebox.at_css("aside")["data-onebox-src"]).to eq(conversation.url)
      expect(onebox.at_css("header.source > .onebox-ai-llm-title").text).to eq(
        I18n.t("discourse_ai.share_ai.onebox_title", llm_name: conversation.llm_name),
      )
      expect(onebox.at_css(".onebox-ai-llm-title").element_children).to be_empty
      expect(onebox.at_css("article.onebox-body > h3 > a").text).to eq(conversation.title)
      expect(onebox.at_css("h3 > a").element_children).to be_empty
      expect(onebox.css("a").map { |link| link["href"] }).to eq([conversation.url] * 3)
      expect(onebox.at_css("header.source > a")["rel"]).to eq("nofollow ugc noopener")
      expect(onebox.at_css("header.source > a")["target"]).to eq("_blank")
      expect(onebox.at_css("article > a").text).to eq(read_more)
      expect(onebox.at_css("article > a").element_children).to be_empty
    end

    it "escapes title and username" do
      malicious_username = %(user"><img src=x onerror=alert(1)>)
      malicious_title = %(title</a><script>alert("x")</script>)
      user.update_columns(username: malicious_username, username_lower: malicious_username.downcase)
      topic.update_column(:title, malicious_title)

      Fabricate(:post, topic: topic, user: user, post_number: 3, raw: "safe post")

      conversation = described_class.share_conversation(user, topic)

      onebox = conversation.onebox

      expect(onebox).to include("user&quot;&gt;&lt;img src=x onerror=alert(1)&gt;")
      expect(onebox).to include("title&lt;/a&gt;&lt;script&gt;alert(&quot;x&quot;)&lt;/script&gt;")

      expect(onebox).not_to include("<img src=x onerror=alert(1)>")
      expect(onebox).not_to include(%(<script>alert("x")</script>))
    end
  end

  describe "#html_excerpt" do
    it "renders usernames as text and preserves cooked excerpt content" do
      username = %(Renée & <reader> "東京")
      user.update_columns(username: username, username_lower: username.downcase)
      cooked = <<~HTML
        <p><strong>Research &amp; development</strong> with <em>care</em>
        <a href="https://example.com/guide">guide</a>
        <span class="hashtag-icon-placeholder">tag</span></p>
        <details><summary>Notes</summary><p>Internal notes</p></details>
      HTML
      post1.update_columns(user_id: user.id, cooked: cooked)
      conversation = described_class.share_conversation(user, topic, max_posts: 1)

      html = conversation.html_excerpt
      excerpt = Nokogiri::HTML5.fragment(html)

      expect(html).to be_a(String)
      expect(excerpt.at_css("p > b").text).to eq(username)
      expect(excerpt.at_css("p > b").element_children).to be_empty
      expect(excerpt.at_css("p").text).to include("Research & development", "care", "guide")
      expect(excerpt.at_css("p > span.hashtag-icon-placeholder").text).to eq("tag")
      expect(excerpt.css("p a, details")).to be_empty
      expect(excerpt.css("a").map { |link| link["href"] }).to eq([conversation.url])
    end

    it "limits each cooked excerpt to 400 characters" do
      post1.update_column(:cooked, "<p>#{"a" * 450}</p>")
      conversation = described_class.share_conversation(user, topic, max_posts: 1)

      excerpt = Nokogiri::HTML5.fragment(conversation.html_excerpt)

      expect(excerpt.at_css("p").text).to eq("#{post1.user.username}: #{"a" * 400}…")
    end

    it "includes the paragraph crossing 1000 HTML characters before stopping" do
      user.update_columns(username: "reader", username_lower: "reader")
      conversation = described_class.share_conversation(user, topic)
      conversation.context =
        ["a" * 399, "b" * 399, "c" * 136, "fourth", "fifth"].map.with_index do |text, index|
          {
            id: index + 1,
            user_id: user.id,
            created_at: Time.current.iso8601,
            cooked: "<p>#{text}</p>",
          }
        end

      excerpt = Nokogiri::HTML5.fragment(conversation.html_excerpt)

      expect(excerpt.css("p").map(&:text)).to eq(
        [
          "reader: #{"a" * 399}",
          "reader: #{"b" * 399}",
          "reader: #{"c" * 136}",
          "reader: fourth",
          "...",
        ],
      )
      expect(excerpt.element_children.last.name).to eq("a")
      expect(excerpt.element_children.last["href"]).to eq(conversation.url)
    end
  end
end
