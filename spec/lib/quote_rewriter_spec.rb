# frozen_string_literal: true

RSpec.describe QuoteRewriter do
  subject(:quote_rewriter) { described_class.new(post.id) }

  before { stub_image_size }

  let(:user) { Fabricate(:user, username: "codinghorror") }
  let(:topic) { Fabricate(:topic, user: user) }
  let(:post) { create_post(post_attributes.merge(topic_id: topic.id)) }

  let(:quoted_post) { create_post(user: user, topic: topic, post_number: 1, raw: "quoted post") }
  let(:avatar_url) { user.avatar_template_url.gsub("{size}", "48") }

  describe "#rewrite_raw_username" do
    context "when using the old quote format" do
      let(:post_attributes) { { raw: <<~RAW } }
            [quote="codinghorror, post:1, topic:#{quoted_post.topic.id}"]
            quoted post
            [/quote]
          RAW

      it "rewrites the username" do
        expect(quote_rewriter.rewrite_raw_username(post.raw, "codinghorror", "codingterror")).to eq(
          <<~RAW.strip,
          [quote="codingterror, post:1, topic:#{quoted_post.topic.id}"]
          quoted post
          [/quote]
        RAW
        )
      end
    end

    context "when using the new quote format" do
      let(:post_attributes) { { raw: <<~RAW } }
            [quote="Jeff, post:1, topic:#{quoted_post.topic.id}, username:codinghorror"]
            quoted post
            [/quote]
          RAW

      it "rewrites the username" do
        expect(quote_rewriter.rewrite_raw_username(post.raw, "codinghorror", "codingterror")).to eq(
          <<~RAW.strip,
          [quote="Jeff, post:1, topic:#{quoted_post.topic.id}, username:codingterror"]
          quoted post
          [/quote]
        RAW
        )
      end
    end
  end

  describe "#rewrite_raw_display_name" do
    context "when using the old quote format" do
      let(:post_attributes) { { raw: <<~RAW } }
            [quote="codinghorror, post:1, topic:#{quoted_post.topic.id}"]
            quoted post
            [/quote]
          RAW

      it "does nothing because the username hasn't changed" do
        expect(quote_rewriter.rewrite_raw_display_name(post.raw, "Jeff", "Mr. Atwood")).to eq(
          <<~RAW.strip,
          [quote="codinghorror, post:1, topic:#{quoted_post.topic.id}"]
          quoted post
          [/quote]
        RAW
        )
      end
    end

    context "when using the new quote format" do
      let(:post_attributes) { { raw: <<~RAW } }
            [quote="Jeff, post:1, topic:#{quoted_post.topic.id}, username:codinghorror"]
            quoted post
            [/quote]
          RAW

      it "rewrites the display name" do
        expect(quote_rewriter.rewrite_raw_display_name(post.raw, "Jeff", "Mr. Atwood")).to eq(
          <<~RAW.strip,
          [quote="Mr. Atwood, post:1, topic:#{quoted_post.topic.id}, username:codinghorror"]
          quoted post
          [/quote]
        RAW
        )
      end
    end
  end

  describe "#rewrite_cooked_display_name" do
    let(:doc) { Nokogiri::HTML5.fragment(post.cooked) }

    context "when using the old quote format" do
      let(:post_attributes) { { raw: <<~RAW } }
            [quote="codinghorror, post:1, topic:#{quoted_post.topic.id}"]
            quoted post
            [/quote]
          RAW

      it "does nothing because the display name is the username" do
        expect(quote_rewriter.rewrite_cooked_display_name(doc, "Jeff", "Mr. Atwood").to_html).to eq(
          post.cooked.strip,
        )
      end
    end

    context "when using the new quote format" do
      let(:post_attributes) { { raw: <<~RAW } }
            [quote="Jeff, post:1, topic:#{quoted_post.topic.id}, username:codinghorror"]
            quoted post
            [/quote]
          RAW

      it "rewrites the display name" do
        expect(
          quote_rewriter.rewrite_cooked_display_name(doc, "Jeff", "Mr. Atwood").to_html,
        ).to match_html(<<~HTML.strip)
          <aside class="quote no-group" data-username="codinghorror" data-post="1" data-topic="#{quoted_post.topic.id}">
          <div class="title">
          <div class="quote-controls"></div>
          <img loading="lazy" alt="" width="24" height="24" src="#{avatar_url}" class="avatar"> Mr. Atwood:</div>
          <blockquote>
          <p>quoted post</p>
          </blockquote>
          </aside>
        HTML
      end
    end
  end
end
