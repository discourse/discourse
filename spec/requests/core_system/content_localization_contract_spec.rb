# frozen_string_literal: true

RSpec.describe TopicsController, type: :request do
  fab!(:user) { Fabricate(:user, locale: "ja") }
  fab!(:topic) { Fabricate(:topic, title: "Life strategies from The Art of War", locale: "en") }
  fab!(:first_post) do
    Fabricate(:post, topic:, locale: "en", raw: "The masterpiece is about military strategy")
  end

  describe "#show" do
    before do
      SiteSetting.default_locale = "en"
      SiteSetting.allow_user_locale = true
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_supported_locales = "en|ja"
      user.user_option.update!(automatically_translate: true)
      sign_in(user)
    end

    it "selects Japanese title and post content for a Japanese reader" do
      translation =
        Fabricate(
          :topic_localization,
          topic:,
          locale: "ja",
          title: "孫子兵法からの人生戦略",
          fancy_title: "孫子兵法からの人生戦略",
        )
      post_translation =
        Fabricate(:post_localization, post: first_post, locale: "ja", cooked: "<p>傑作の翻訳</p>")

      expect_topic_content(
        topic:,
        post: first_post,
        title: translation.fancy_title,
        cooked: post_translation.cooked,
      )
    end

    it "matches an English translation for an en_GB reader" do
      SiteSetting.content_localization_use_default_locale_when_unsupported = false
      user.update!(locale: "en_GB")
      japanese_post = Fabricate(:post, topic:, locale: "ja", raw: "将とは、智・信・仁・勇・厳なり。")
      translation =
        Fabricate(
          :post_localization,
          post: japanese_post,
          locale: "en",
          cooked: "<p>A general is one who ..</p>",
        )

      expect_topic_content(
        topic:,
        post: japanese_post,
        title: topic.fancy_title,
        cooked: translation.cooked,
      )
    end

    it "keeps content with no source locale unchanged with localization enabled or disabled" do
      user.update!(locale: "el")
      SiteSetting.content_localization_use_default_locale_when_unsupported = true
      topic.update!(locale: nil)
      first_post.update!(locale: nil)
      Fabricate(
        :topic_localization,
        topic:,
        locale: "en",
        title: "An unused translation",
        fancy_title: "An unused translation",
      )
      Fabricate(:post_localization, post: first_post, locale: "en", cooked: "<p>Unused</p>")

      expect_topic_content(
        topic:,
        post: first_post,
        title: topic.fancy_title,
        cooked: first_post.cooked,
      )

      SiteSetting.content_localization_enabled = false

      expect_topic_content(
        topic:,
        post: first_post,
        title: topic.fancy_title,
        cooked: first_post.cooked,
      )
    end

    it "keeps original content when the unsupported reader has no fallback translation" do
      user.update!(locale: "el")
      SiteSetting.content_localization_use_default_locale_when_unsupported = true
      topic.update!(locale: "ja", title: "ジョジョの奇妙な冒険についての話")
      first_post.update!(locale: "ja", cooked: "<p>皆さんはご存知ですか？</p>")

      expect_topic_content(
        topic:,
        post: first_post,
        title: topic.fancy_title,
        cooked: first_post.cooked,
      )
    end

    it "ignores an anonymous locale parameter for an authenticated English reader" do
      user.update!(locale: "en")
      SiteSetting.set_locale_from_param = true
      SiteSetting.set_locale_from_cookie = true
      Fabricate(
        :topic_localization,
        topic:,
        locale: "ja",
        title: "孫子兵法からの人生戦略",
        fancy_title: "孫子兵法からの人生戦略",
      )

      get "#{topic.relative_url}.json", params: { tl: "ja" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["fancy_title"]).to eq(topic.fancy_title)

      get topic.relative_url, params: { tl: "ja" }

      expect(response.status).to eq(200)
      expect(Nokogiri.HTML5(response.body).at_css("title").text).to include(topic.title)
    end
  end

  private

  def expect_topic_content(topic:, post:, title:, cooked:)
    get "#{topic.relative_url}.json"

    expect(response.status).to eq(200)
    expect(response.parsed_body["fancy_title"]).to eq(title)
    posts = response.parsed_body.dig("post_stream", "posts")
    expect(posts.find { |entry| entry["id"] == post.id }.fetch("cooked")).to eq(cooked)

    get topic.relative_url, headers: { "User-Agent" => "Googlebot" }

    expect(response.status).to eq(200)
    document = Nokogiri.HTML5(response.body)
    expect(document.at_css("title").text).to include(Nokogiri::HTML5.fragment(title).text)
    expect(document.at_css("body")["class"].split).to include("crawler")
    post_content = document.at_css("#post_#{post.post_number} .post")
    expect(post_content).to be_present
    expect(post_content.text).to include(Nokogiri::HTML5.fragment(cooked).text)
  end
end
