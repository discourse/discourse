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

    def twitter_card
      image_url ? "summary_large_image" : "summary"
    end

    def published_time
      @publication.published_at&.iso8601
    end

    def modified_time
      @publication.article_updated_at&.iso8601
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
        "author" => {
          "@type" => "Person",
          "name" => @revision.data["author_name"],
        },
        "image" => image_url,
      }.compact.to_json
    end
  end
end
