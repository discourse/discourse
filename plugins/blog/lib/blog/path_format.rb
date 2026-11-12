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
      sample.match?(Publication::PATH_PATTERN) && Publication.decodable_path?(sample) &&
        !Publication.reserved_path?(sample) && !Publication.traversal_path?(sample)
    end

    # A slug longer than max_length allows is shortened, sharing the room between
    # every {slug} in the template.
    def render(slug:, id:, date:, max_length: nil)
      date = date.utc
      values = {
        "year" => date.strftime("%Y"),
        "month" => date.strftime("%m"),
        "day" => date.strftime("%d"),
        "id" => id.to_s,
      }
      slug = slug.to_s
      slugs = @template.scan(TOKEN).count(["slug"])
      if max_length && slugs > 0
        room = (max_length - expand(values.merge("slug" => "")).length) / slugs
        slug = shorten(slug, room) if slug.length > room
      end
      expand(values.merge("slug" => slug))
    end

    private

    # Percent-encoded slugs must not be cut partway through an escape or a UTF-8 character.
    def shorten(slug, room)
      slug = slug[0, room].sub(/%\h?\z/, "")
      while (tail = slug[/(?:%[89a-fA-F]\h)+\z/]) && !utf8?(tail)
        slug = slug.delete_suffix(tail[-3..])
      end
      slug.sub(/-+\z/, "")
    end

    def utf8?(encoded)
      [encoded.delete("%")].pack("H*").force_encoding(Encoding::UTF_8).valid_encoding?
    end

    def expand(values)
      @template.gsub(TOKEN) { values.fetch($1, $&) }
    end
  end
end
