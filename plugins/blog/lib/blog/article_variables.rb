# frozen_string_literal: true

module ::Blog
  class ArticleVariables
    include ActionView::Helpers::DateHelper

    class Placeholder
      def to_h
        {
          "title" => I18n.t("blog.themes.sample_article"),
          "url" => Configuration.url("/example"),
          "excerpt" => I18n.t("blog.themes.sample_body"),
          "standfirst" => "",
          "author" => nil,
          "author_url" => nil,
          "authors" => [],
          "published_at" => nil,
          "date" => "",
          "relative_date" => "",
          "reading_time" => "",
          "featured" => false,
          "image_url" => nil,
          "image_alt" => "",
          "discussion_url" => Discourse.base_url,
          "replies" => 0,
          "replies_label" => "",
          "index" => "01",
          "updated_label" => nil,
          "body_html" => "<p>#{ERB::Util.html_escape(I18n.t("blog.themes.sample_body"))}</p>",
          "tags" => [],
          "cover_url" => nil,
          "cover_alt" => "",
          "cover_width" => nil,
          "cover_height" => nil,
        }
      end
    end

    def self.placeholder
      Placeholder.new
    end

    def initialize(
      publication,
      revision: publication.article,
      topic: publication.discussion_topic,
      preview_token: nil,
      co_author_users: nil
    )
      @publication = publication
      @revision = revision
      @topic = topic
      @preview_token = preview_token
      @co_author_users = co_author_users
    end

    def summary(index: 0)
      {
        "title" => @revision.title,
        "url" => url(@publication.path),
        "excerpt" => @publication.display_excerpt,
        "standfirst" => @revision.data["excerpt"].presence,
        "author" => authors.map { _1.values_at("name", "separator").join }.join.presence,
        "author_url" => authors.first&.dig("url"),
        "authors" => authors,
        "published_at" => published_at&.iso8601,
        "date" => published_at && format_date(published_at),
        "relative_date" =>
          published_at &&
            I18n.t("blog.time_ago", time: distance_of_time_in_words(published_at, Time.current)),
        "reading_time" => I18n.t("blog.reading_time", count: @revision.reading_minutes),
        "featured" => @publication.featured?,
        "image_url" => @revision.absolute_image_url,
        "image_alt" => cover_alt,
        "discussion_url" => @topic.url,
        "replies" => replies,
        "replies_label" => I18n.t("blog.replies", count: replies),
        "index" => format("%02d", index + 1),
        "updated_label" => updated_label,
      }
    end

    def to_h
      summary.merge(
        "body_html" => TemplateRenderer::Html.new(ArticleHtml.render(@revision.cooked)),
        "tags" =>
          @revision.public_tags.map do |tag|
            { "name" => tag.name, "url" => url("/tag/#{tag.slug}") }
          end,
        "cover_url" => (@revision.absolute_image_url if @revision.cover?),
        "cover_alt" => cover_alt,
        "cover_width" => (@revision.data["cover_width"] if @revision.cover?),
        "cover_height" => (@revision.data["cover_height"] if @revision.cover?),
      )
    end

    private

    def authors
      @authors ||=
        begin
          credited = @revision.authors(@topic&.user, users: @co_author_users)
          credited.each_with_index.map do |(user, name), index|
            {
              "name" => name,
              "url" => url(Revision.author_path(user)),
              "separator" => author_separator(index, credited.size),
            }
          end
        end
    end

    # Joins names as "A, B and C".
    def author_separator(index, count)
      return "" if index == count - 1
      return I18n.t("blog.last_author_separator") if index == count - 2
      I18n.t("blog.author_separator")
    end

    # Only an explicit cover has alt text; a fallback image comes from the article body.
    def cover_alt
      @revision.cover? ? @revision.data["cover_alt"].to_s : ""
    end

    def published_at
      @publication.published_at
    end

    def replies
      [@topic.posts_count - 1, 0].max
    end

    def updated_label
      return if !published_at
      updated_at = @publication.article_updated_at
      return if updated_at.to_date <= published_at.to_date
      I18n.t("blog.updated", date: format_date(updated_at))
    end

    def format_date(date)
      I18n.l(date, format: :date_only)
    end

    def url(path)
      Configuration.url(path, preview_token: @preview_token)
    end
  end
end
