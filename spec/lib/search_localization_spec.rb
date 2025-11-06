# frozen_string_literal: true

RSpec.describe Search do
  fab!(:admin)
  fab!(:user) { Fabricate(:user, locale: "fr") }
  fab!(:chinese_user) { Fabricate(:user, locale: "zh_CN") }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  before do
    SiteSetting.content_localization_enabled = true
    SiteSetting.allow_user_locale = true
    SiteSetting.default_locale = "en"
  end

  describe ".segment_chinese? with locale parameter" do
    it "returns true for Chinese locales" do
      expect(Search.segment_chinese?(locale: "zh_CN")).to be true
      expect(Search.segment_chinese?(locale: "zh_TW")).to be true
    end

    it "returns false for non-Chinese locales" do
      expect(Search.segment_chinese?(locale: "en")).to be false
      expect(Search.segment_chinese?(locale: "ja")).to be false
    end

    it "returns true when search_tokenize_chinese is enabled" do
      SiteSetting.search_tokenize_chinese = true
      expect(Search.segment_chinese?(locale: "en")).to be true
    end
  end

  describe ".segment_japanese? with locale parameter" do
    it "returns true for Japanese locale" do
      expect(Search.segment_japanese?(locale: "ja")).to be true
    end

    it "returns false for non-Japanese locales" do
      expect(Search.segment_japanese?(locale: "en")).to be false
      expect(Search.segment_japanese?(locale: "zh_CN")).to be false
    end

    it "returns true when search_tokenize_japanese is enabled" do
      SiteSetting.search_tokenize_japanese = true
      expect(Search.segment_japanese?(locale: "en")).to be true
    end
  end

  describe ".prepare_data with locale parameter" do
    it "applies Chinese segmentation when locale is Chinese" do
      text = "这是一个测试"
      result = Search.prepare_data(text, :index, locale: "zh_CN")

      # Chinese text should be segmented (contain spaces)
      expect(result).to include(" ")
    end

    it "applies Japanese segmentation when locale is Japanese" do
      text = "これはテストです"
      result = Search.prepare_data(text, :index, locale: "ja")

      # Japanese text should be segmented
      expect(result).to be_present
    end

    it "applies default processing for non-CJK locales" do
      text = "This is a test"
      result = Search.prepare_data(text, :index, locale: "en")

      expect(result).to eq("This is a test")
    end

    it "respects locale parameter over site default" do
      SiteSetting.default_locale = "en"

      # Chinese text with Chinese locale should be segmented
      chinese_text = "测试内容"
      result = Search.prepare_data(chinese_text, :index, locale: "zh_CN")
      expect(result).to include(" ") # Segmented

      # Same text with English locale should not be specially segmented
      result_en = Search.prepare_data(chinese_text, :index, locale: "en")
      # Without Chinese segmentation, text is just cleaned
      expect(result).not_to eq(result_en)
    end
  end

  describe "locale-aware search queries" do
    before do
      # Create a post with localization
      PostLocalization.create!(
        post: post,
        locale: "fr",
        raw: "Contenu en français moteur",
        cooked: "<p>Contenu en français moteur</p>",
        post_version: 1,
        localizer_user_id: admin.id,
      )

      SearchIndexer.index(post, force: true)
    end

    it "finds posts by localized content when user has matching locale" do
      results = Search.execute("moteur", guardian: Guardian.new(user))

      # Should find the post via French localization
      expect(results.posts.map(&:id)).to include(post.id)
    end

    it "prefers user locale over default locale in search results" do
      # Create post with both English and French content
      post.update!(raw: "English engine content", cooked: "<p>English engine content</p>")

      PostLocalization.create!(
        post: post,
        locale: "fr",
        raw: "Moteur français spécifique",
        cooked: "<p>Moteur français spécifique</p>",
        post_version: 2,
        localizer_user_id: admin.id,
      )

      SearchIndexer.index(post, force: true)

      # French user searching should use French localization
      results = Search.execute("français", guardian: Guardian.new(user))
      expect(results.posts.map(&:id)).to include(post.id)
    end

    it "falls back to default locale when user locale is not available" do
      english_user = Fabricate(:user, locale: "en")

      results = Search.execute(post.topic.title, guardian: Guardian.new(english_user))

      # Should find via default locale
      expect(results.posts.map(&:id)).to include(post.id)
    end

    it "handles CJK content correctly based on localization locale" do
      chinese_post = Fabricate(:post, topic: Fabricate(:topic))

      PostLocalization.create!(
        post: chinese_post,
        locale: "zh_CN",
        raw: "这是一个测试内容",
        cooked: "<p>这是一个测试内容</p>",
        post_version: 1,
        localizer_user_id: admin.id,
      )

      SearchIndexer.index(chinese_post, force: true)

      # Chinese user should be able to search with Chinese terms
      results = Search.execute("测试", guardian: Guardian.new(chinese_user))

      # Should find the post (depending on Chinese segmentation)
      expect(results.posts.map(&:id)).to include(chinese_post.id)
    end

    it "respects guardian permissions for localized content" do
      private_topic = Fabricate(:private_message_topic, user: admin)
      private_post = Fabricate(:post, topic: private_topic)

      PostLocalization.create!(
        post: private_post,
        locale: "fr",
        raw: "Message privé secret",
        cooked: "<p>Message privé secret</p>",
        post_version: 1,
        localizer_user_id: admin.id,
      )

      SearchIndexer.index(private_post, force: true)

      # User without access should not find it
      results = Search.execute("secret", guardian: Guardian.new(user))
      expect(results.posts.map(&:id)).not_to include(private_post.id)

      # Admin should find it
      results = Search.execute("secret", guardian: Guardian.new(admin))
      expect(results.posts.map(&:id)).to include(private_post.id)
    end
  end

  describe "anonymous user search" do
    it "works without user locale" do
      PostLocalization.create!(
        post: post,
        locale: "fr",
        raw: "Contenu publique",
        cooked: "<p>Contenu publique</p>",
        post_version: 1,
        localizer_user_id: admin.id,
      )

      SearchIndexer.index(post, force: true)

      # Anonymous users should still be able to search
      results = Search.execute(post.topic.title, guardian: Guardian.new(nil))
      expect(results.posts).to be_present
    end
  end
end
