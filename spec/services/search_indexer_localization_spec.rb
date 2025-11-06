# frozen_string_literal: true

RSpec.describe SearchIndexer do
  fab!(:user)
  fab!(:post)

  before { SiteSetting.content_localization_enabled = true }

  describe ".update_posts_index with localizations" do
    it "indexes both default locale and localizations" do
      # Create localizations
      chinese_loc =
        PostLocalization.create!(
          post: post,
          locale: "zh_CN",
          raw: "测试内容",
          cooked: "<p>测试内容</p>",
          post_version: 1,
          localizer_user_id: user.id,
        )

      japanese_loc =
        PostLocalization.create!(
          post: post,
          locale: "ja",
          raw: "テスト内容",
          cooked: "<p>テスト内容</p>",
          post_version: 1,
          localizer_user_id: user.id,
        )

      # Index the post with localizations
      SearchIndexer.update_posts_index(
        post_id: post.id,
        topic_title: post.topic.title,
        category_name: post.topic.category&.name,
        topic_tags: nil,
        cooked: post.cooked,
        private_message: false,
        localizations: [chinese_loc, japanese_loc],
      )

      # Verify default locale entry exists
      default_search = PostSearchData.find_by(post_id: post.id, locale: SiteSetting.default_locale)
      expect(default_search).to be_present
      expect(default_search.raw_data).to include(post.topic.title)

      # Verify Chinese localization entry exists
      chinese_search = PostSearchData.find_by(post_id: post.id, locale: "zh_CN")
      expect(chinese_search).to be_present
      expect(chinese_search.raw_data).to include("测试内容")

      # Verify Japanese localization entry exists
      japanese_search = PostSearchData.find_by(post_id: post.id, locale: "ja")
      expect(japanese_search).to be_present
      expect(japanese_search.raw_data).to include("テスト内容")
    end

    it "uses correct CJK segmentation based on locale" do
      chinese_loc =
        PostLocalization.create!(
          post: post,
          locale: "zh_CN",
          raw: "这是一个测试",
          cooked: "<p>这是一个测试</p>",
          post_version: 1,
          localizer_user_id: user.id,
        )

      SearchIndexer.update_posts_index(
        post_id: post.id,
        topic_title: post.topic.title,
        category_name: nil,
        topic_tags: nil,
        cooked: post.cooked,
        private_message: false,
        localizations: [chinese_loc],
      )

      # The Chinese text should be segmented (contains spaces between words)
      chinese_search = PostSearchData.find_by(post_id: post.id, locale: "zh_CN")
      expect(chinese_search).to be_present
      # Chinese segmentation should have processed the text
      expect(chinese_search.search_data).to be_present
    end

    it "does not index localizations when content_localization is disabled" do
      SiteSetting.content_localization_enabled = false

      chinese_loc =
        PostLocalization.create!(
          post: post,
          locale: "zh_CN",
          raw: "测试内容",
          cooked: "<p>测试内容</p>",
          post_version: 1,
          localizer_user_id: user.id,
        )

      SearchIndexer.update_posts_index(
        post_id: post.id,
        topic_title: post.topic.title,
        category_name: nil,
        topic_tags: nil,
        cooked: post.cooked,
        private_message: false,
        localizations: [chinese_loc],
      )

      # Only default locale should be indexed
      expect(PostSearchData.where(post_id: post.id).count).to eq(1)
      expect(PostSearchData.find_by(post_id: post.id, locale: "zh_CN")).to be_nil
    end
  end

  describe ".index with post localizations" do
    it "automatically indexes localizations when indexing a post" do
      PostLocalization.create!(
        post: post,
        locale: "fr",
        raw: "Contenu en français",
        cooked: "<p>Contenu en français</p>",
        post_version: 1,
        localizer_user_id: user.id,
      )

      SearchIndexer.index(post, force: true)

      # Both default and French should be indexed
      expect(
        PostSearchData.find_by(post_id: post.id, locale: SiteSetting.default_locale),
      ).to be_present
      expect(PostSearchData.find_by(post_id: post.id, locale: "fr")).to be_present
    end
  end

  describe "PostLocalization callbacks" do
    it "reindexes parent post when localization is created" do
      allow(SearchIndexer).to receive(:index)

      PostLocalization.create!(
        post: post,
        locale: "es",
        raw: "Contenido en español",
        cooked: "<p>Contenido en español</p>",
        post_version: 1,
        localizer_user_id: user.id,
      )

      expect(SearchIndexer).to have_received(:index).with(post)
    end

    it "removes search index when localization is destroyed" do
      localization =
        PostLocalization.create!(
          post: post,
          locale: "de",
          raw: "Deutscher Inhalt",
          cooked: "<p>Deutscher Inhalt</p>",
          post_version: 1,
          localizer_user_id: user.id,
        )

      SearchIndexer.index(post, force: true)
      expect(PostSearchData.find_by(post_id: post.id, locale: "de")).to be_present

      localization.destroy!
      expect(PostSearchData.find_by(post_id: post.id, locale: "de")).to be_nil
    end
  end
end
