# frozen_string_literal: true

module ::Blog
  # The address template for new articles, such as "/{year}/{month}/{slug}".
  class PathFormat
    TOKEN = /\{(\w+)\}/
    TOKENS = %w[year month day slug id].freeze
    # At least one of these keeps two articles from rendering the same address.
    UNIQUE_TOKENS = %w[slug id].freeze
    MAX_LENGTH = 100

    def self.current
      new(SiteSetting.blog_path_format)
    end

    def initialize(template)
      @template = template.to_s
    end

    def valid?
      tokens = @template.scan(TOKEN).flatten
      return false if @template.length > MAX_LENGTH || tokens.difference(TOKENS).any?
      return false if !tokens.intersect?(UNIQUE_TOKENS)

      sample = render(slug: "article", id: 1, date: Time.utc(2026, 1, 1))
      sample.match?(Publication::PATH_PATTERN) && !Publication.reserved_path?(sample)
    end

    def dated?
      @template.scan(TOKEN).flatten.intersect?(%w[year month day])
    end

    def render(slug:, id:, date:)
      date = date.utc
      values = {
        "year" => date.strftime("%Y"),
        "month" => date.strftime("%m"),
        "day" => date.strftime("%d"),
        "slug" => slug.to_s,
        "id" => id.to_s,
      }
      @template.gsub(TOKEN) { values.fetch($1, $&) }
    end
  end
end
