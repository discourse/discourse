# frozen_string_literal: true

describe "topic_localizations rake tasks" do
  around { |example| capture_stdout { example.run } }

  describe "topic_localizations:backfill_excerpts" do
    fab!(:topic)
    fab!(:first_post) { Fabricate(:post, topic:, post_number: 1) }

    it "backfills excerpt from post localization" do
      topic.update_column(:excerpt, "original excerpt")
      Fabricate(
        :post_localization,
        post: first_post,
        locale: "ja",
        raw: "これは投稿の内容です。",
        cooked: "<p>これは投稿の内容です。</p>",
      )
      topic_localization =
        Fabricate(:topic_localization, topic: topic, locale: "ja", title: "日本語タイトル")

      expect(topic_localization.excerpt).to be_nil

      invoke_rake_task("topic_localizations:backfill_excerpts")

      topic_localization.reload
      expect(topic_localization.excerpt).to eq("これは投稿の内容です。")
    end

    it "skips topic localizations that already have an excerpt" do
      Fabricate(
        :post_localization,
        post: first_post,
        locale: "ja",
        raw: "新しい内容",
        cooked: "<p>新しい内容</p>",
      )
      topic_localization =
        Fabricate(
          :topic_localization,
          topic: topic,
          locale: "ja",
          title: "日本語タイトル",
          excerpt: "既存の抜粋",
        )

      invoke_rake_task("topic_localizations:backfill_excerpts")

      topic_localization.reload
      expect(topic_localization.excerpt).to eq("既存の抜粋")
    end

    it "skips topic localizations without matching post localization" do
      topic.update_column(:excerpt, "original excerpt")
      topic_localization =
        Fabricate(:topic_localization, topic: topic, locale: "ja", title: "日本語タイトル")

      invoke_rake_task("topic_localizations:backfill_excerpts")

      topic_localization.reload
      expect(topic_localization.excerpt).to be_nil
    end

    it "skips topic localizations when topic has empty excerpt" do
      topic.update_column(:excerpt, "")
      Fabricate(
        :post_localization,
        post: first_post,
        locale: "ja",
        raw: "これは投稿の内容です。",
        cooked: "<p>これは投稿の内容です。</p>",
      )
      topic_localization =
        Fabricate(:topic_localization, topic: topic, locale: "ja", title: "日本語タイトル")

      invoke_rake_task("topic_localizations:backfill_excerpts")

      topic_localization.reload
      expect(topic_localization.excerpt).to be_nil
    end
  end
end
