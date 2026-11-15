# frozen_string_literal: true

module ::Blog
  class ArticleMetadata
    def initialize(publication, description:, revision: publication.article)
      @publication = publication
      @revision = revision
      @description = description
    end

    def image_url
      @revision.absolute_image_url
    end

    def image_alt
      @revision.data["cover_alt"].presence if @revision.cover?
    end

    def twitter_card
      image_url ? "summary_large_image" : "summary"
    end

    def published_time
      @publication.published_at&.iso8601
    end

    def modified_time
      @publication.article_updated_at&.iso8601
    end

    def author
      people =
        @revision
          .authors(@publication.discussion_topic&.user)
          .map do |user, name|
            {
              "@type" => "Person",
              "name" => name,
              "url" => "#{Configuration.base_url}#{Revision.author_path(user)}",
            }
          end
      people.many? ? people : people.first
    end

    def schema
      {
        "@context" => "https://schema.org",
        "@type" => "BlogPosting",
        "headline" => @revision.title,
        "description" => @description,
        "url" => @publication.url,
        "mainEntityOfPage" => @publication.url,
        "datePublished" => published_time,
        "dateModified" => modified_time,
        "author" => author,
        "image" => image_url,
      }.compact.to_json
    end
  end
end
