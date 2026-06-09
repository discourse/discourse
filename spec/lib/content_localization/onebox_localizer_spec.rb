# frozen_string_literal: true

RSpec.describe ContentLocalization::OneboxLocalizer do
  fab!(:reader) { Fabricate(:user, locale: "ja") }
  fab!(:source_topic, :topic)
  fab!(:source_post) do
    Fabricate(:post, topic: source_topic, post_number: 1, locale: "ja", raw: "見てください")
  end

  before { SiteSetting.content_localization_enabled = true }

  def add_localized_onebox(index)
    topic = Fabricate(:topic, title: "Linked topic number #{index} goes here", locale: "en")
    post = Fabricate(:post, topic: topic, post_number: 1, locale: "en", raw: "body number #{index}")
    Fabricate(:topic_localization, topic: topic, locale: "ja", title: "翻訳タイトル#{index}")
    Fabricate(:post_localization, post: post, locale: "ja", cooked: "<p>翻訳本文#{index}</p>")
    TopicLink.create!(
      topic: source_topic,
      post: source_post,
      user: source_post.user,
      url: post.url,
      domain: Discourse.current_hostname,
      internal: true,
      quote: true,
      reflection: false,
      link_topic_id: topic.id,
      link_post_id: post.id,
    )
  end

  def build
    I18n.with_locale(:ja) do
      described_class.build(
        posts: [source_post],
        guardian: Guardian.new(reader),
        category: source_topic.category,
        locale: :ja,
      )
    end
  end

  it "batches its lookups into one query each regardless of onebox count (no N+1)" do
    add_localized_onebox(1)
    add_localized_onebox(2)
    add_localized_onebox(3)

    queries = track_sql_queries { build }

    expect(queries.count { |q| q =~ /FROM "?topic_links"?/ }).to eq(1)
    expect(queries.count { |q| q =~ /FROM "?topics"?/ }).to eq(1)
    expect(queries.count { |q| q =~ /FROM "?posts"?/ }).to eq(1)
    expect(queries.count { |q| q =~ /FROM "?topic_localizations"?/ }).to eq(1)
    expect(queries.count { |q| q =~ /FROM "?post_localizations"?/ }).to eq(1)
  end
end
