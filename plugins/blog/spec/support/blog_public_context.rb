# frozen_string_literal: true

RSpec.shared_context "with a public blog" do
  fab!(:blog_category, :category)

  before { enable_blog!(category: blog_category) }

  def publish_blog_article(
    topic = Fabricate(:topic, category: blog_category),
    published_at: 1.day.ago,
    **attributes
  )
    Fabricate(:post, topic:)
    publication =
      Blog::Publication.create!(
        topic:,
        discussion_topic: topic,
        path: "/story-#{topic.id}",
        published: true,
        published_at:,
        **attributes,
      )
    publication.paths.create!(path: publication.path)
    publication
  end
end
