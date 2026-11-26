# frozen_string_literal: true

RSpec.describe Blog::ArticleVariables do
  include_context "with a public blog"

  fab!(:tag) { Fabricate(:tag, name: "field-notes") }
  fab!(:publication) do
    publish_blog_article(
      Fabricate(:topic, category: blog_category, tags: [tag]),
      path: "/field-story",
      excerpt: "A standfirst",
      published_at: 3.days.ago,
    )
  end

  let(:topic) { publication.discussion_topic }

  before { freeze_time }

  describe "#summary" do
    it "describes an article for listings" do
      topic.update_columns(posts_count: 3)

      expect(described_class.new(publication).summary(index: 2)).to eq(
        "title" => topic.title,
        "url" => "https://blog.example.com/field-story",
        "excerpt" => "A standfirst",
        "standfirst" => "A standfirst",
        "author" => topic.user.name,
        "author_url" => "https://blog.example.com/author/#{topic.user.username_lower}",
        "authors" => [
          {
            "name" => topic.user.name,
            "url" => "https://blog.example.com/author/#{topic.user.username_lower}",
            "separator" => "",
          },
        ],
        "published_at" => publication.published_at.iso8601,
        "date" => I18n.l(publication.published_at, format: :date_only),
        "relative_date" => I18n.t("blog.time_ago", time: "3d"),
        "reading_time" => I18n.t("blog.reading_time", count: 1),
        "featured" => false,
        "image_url" => nil,
        "image_alt" => "",
        "discussion_url" => topic.url,
        "replies" => 2,
        "replies_label" => I18n.t("blog.replies", count: 2),
        "index" => "03",
        "updated_label" => I18n.t("blog.updated", date: I18n.l(Time.current, format: :date_only)),
      )
    end

    it "leaves out the byline when the system user owns the article" do
      topic.update!(user: Discourse.system_user)

      expect(described_class.new(publication).summary).to include(
        "author" => nil,
        "author_url" => nil,
        "authors" => [],
      )
    end

    it "credits co-authors after the owner with the names they had when published" do
      ada = Fabricate(:user, name: "Ada")
      bob = Fabricate(:user, name: "Bob")
      gone = Fabricate(:user, name: "Gone")
      credits = Blog::Revision.co_author_credits([ada.id, gone.id, bob.id])
      revision = Blog::Revision.new(data: publication.article.data.merge("co_authors" => credits))
      ada.update!(name: "Ada Renamed")
      gone.destroy!

      summary = described_class.new(publication, revision:).summary

      expect(summary["author"]).to eq("#{topic.user.name}, Ada and Bob")
      expect(summary["authors"].map { _1.values_at("name", "separator") }).to eq(
        [[topic.user.name, ", "], ["Ada", " and "], ["Bob", ""]],
      )
      expect(summary["authors"].second["url"]).to eq(
        "https://blog.example.com/author/#{ada.username_lower}",
      )
    end

    it "omits the update label when the article was not revised on a later day" do
      publication.update_columns(last_published_at: publication.published_at)
      topic.update_columns(posts_count: 0)

      expect(described_class.new(publication).summary).to include(
        "updated_label" => nil,
        "replies" => 0,
      )
    end

    it "keeps a theme preview on the article link" do
      expect(described_class.new(publication, preview_token: "preview-token").summary).to include(
        "url" => "https://blog.example.com/field-story?blog_theme_preview=preview-token",
      )
    end

    it "describes the given revision and discussion instead of the published ones" do
      revision = Blog::Revision.new(data: publication.article.data.merge("title" => "Draft title"))
      other_topic = Fabricate(:topic)

      expect(described_class.new(publication, revision:, topic: other_topic).summary).to include(
        "title" => "Draft title",
        "discussion_url" => other_topic.url,
      )
    end
  end

  describe "#to_h" do
    it "adds the body and public tags for the article page" do
      values = described_class.new(publication).to_h

      expect(values).to include(described_class.new(publication).summary)
      expect(values["body_html"]).to be_a(Blog::TemplateRenderer::Html)
      expect(values["body_html"]).to include(topic.first_post.cooked)
      expect(values["tags"]).to eq(
        [{ "name" => tag.name, "url" => "https://blog.example.com/tag/#{tag.slug}" }],
      )
    end
  end

  describe "cover image" do
    fab!(:cover) { Fabricate(:upload, width: 1200, height: 630) }

    it "offers an explicit cover with its alt text and size" do
      data =
        publication.article.data.merge(
          "image_url" => cover.url,
          "cover_upload_id" => cover.id,
          "cover_alt" => "A lighthouse at dusk",
          "cover_width" => 1200,
          "cover_height" => 630,
        )

      values = described_class.new(publication, revision: Blog::Revision.new(data:)).to_h

      expect(values).to include(
        "image_url" => UrlHelper.absolute(cover.url),
        "image_alt" => "A lighthouse at dusk",
        "cover_url" => UrlHelper.absolute(cover.url),
        "cover_alt" => "A lighthouse at dusk",
        "cover_width" => 1200,
        "cover_height" => 630,
      )
    end

    it "doesn't treat an image from the article body as a cover" do
      data = publication.article.data.merge("image_url" => cover.url)

      values = described_class.new(publication, revision: Blog::Revision.new(data:)).to_h

      expect(values).to include(
        "image_url" => UrlHelper.absolute(cover.url),
        "image_alt" => "",
        "cover_url" => nil,
      )
    end
  end

  describe ".placeholder" do
    it "offers a sample article before anything is published" do
      expect(described_class.placeholder.to_h).to include(
        "title" => I18n.t("blog.themes.sample_article"),
        "url" => "https://blog.example.com/example",
        "body_html" => "<p>#{ERB::Util.html_escape(I18n.t("blog.themes.sample_body"))}</p>",
        "tags" => [],
      )
    end
  end
end
