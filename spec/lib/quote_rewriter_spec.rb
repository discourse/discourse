# frozen_string_literal: true

RSpec.describe QuoteRewriter do
  subject(:quote_rewriter) { described_class.new(user.id) }

  before { stub_image_size }

  let(:user) { Fabricate(:user, username: "codinghorror") }
  let(:topic) { Fabricate(:topic, user: user) }
  let(:post) { create_post(post_attributes.merge(topic_id: topic.id)) }

  let(:quoted_post) { create_post(user: user, topic: topic, post_number: 1, raw: "quoted post") }
  let(:avatar_url) { user.avatar_template_url.gsub("{size}", "48") }

  describe "#rewrite_raw_username" do
    before { SiteSetting.enable_names = false }

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

  describe "#rewrite_cooked_username" do
    before { SiteSetting.enable_names = false }

    let(:post_attributes) { { raw: <<~RAW } }
          [quote="codinghorror, post:1, topic:#{quoted_post.topic.id}"]
          quoted post
          [/quote]
        RAW

    it "rewrites the username when names are disabled" do
      doc = Nokogiri::HTML5.fragment(post.cooked)
      avatar_img = PrettyText.avatar_img(user.avatar_template, "tiny")

      quote_rewriter.rewrite_cooked_username(doc, "codinghorror", "codingterror", avatar_img)

      quote = doc.at_css("aside.quote")

      expect(quote["data-username"]).to eq("codingterror")
      expect(quote.at_css(".title").text.squish).to eq("codingterror:")
    end
  end

  describe "#rewrite_display_name" do
    before { SiteSetting.enable_names = false }

    context "when the raw quote uses a username attribution" do
      let(:post_attributes) { { raw: <<~RAW } }
            [quote="codinghorror, post:1, topic:#{quoted_post.topic.id}"]
            quoted post
            [/quote]
          RAW

      it "does not add the new display name to raw or cooked" do
        rewritten =
          quote_rewriter.rewrite_display_name(
            raw: post.raw,
            cooked: post.cooked,
            old_display_name: "codinghorror",
            new_display_name: "Jeff Atwood",
            username: "codinghorror",
          )

        expect(rewritten[:raw]).to eq(post.raw)
        expect(rewritten[:cooked]).to eq(post.cooked)
      end
    end

    context "when the raw quote uses a display name attribution" do
      let(:post_attributes) { { raw: <<~RAW } }
            [quote="Jeff, post:1, topic:#{quoted_post.topic.id}, username:codinghorror"]
            quoted post
            [/quote]
          RAW

      it "replaces the existing display name with the username in raw and cooked" do
        rewritten =
          quote_rewriter.rewrite_display_name(
            raw: post.raw,
            cooked: post.cooked,
            old_display_name: "Jeff",
            new_display_name: "Mr. Atwood",
            username: "codinghorror",
          )

        expect(rewritten[:raw]).to include(
          %([quote="codinghorror, post:1, topic:#{quoted_post.topic.id}"]),
        )
        quote = Nokogiri::HTML5.fragment(rewritten[:cooked]).at_css("aside.quote")

        expect(quote["data-display-name"]).to be_nil
        expect(quote.at_css(".title").text.squish).to eq("codinghorror:")
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
          <aside class="quote no-group" data-username="codinghorror" data-display-name="Mr. Atwood" data-post="1" data-topic="#{quoted_post.topic.id}">
          <div class="title">
          <div class="quote-controls"></div>
          <img alt="" width="24" height="24" src="#{avatar_url}" class="avatar"> Mr. Atwood:</div>
          <blockquote>
          <p>quoted post</p>
          </blockquote>
          </aside>
        HTML
      end
    end
  end
end
