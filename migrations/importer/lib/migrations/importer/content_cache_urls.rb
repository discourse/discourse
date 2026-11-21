# frozen_string_literal: true

require "nokogiri"

module Migrations
  module Importer
    class ContentCacheUrls
      class Unresolved < StandardError
      end

      URL_ATTRIBUTES = %w[href src poster data-orig-src data-download-href].freeze

      def initialize(source, destination)
        @replacements =
          source
            .filter_map do |role, base|
              next if base.blank?
              [base.delete_suffix("/"), destination[role]&.delete_suffix("/")]
            end
            .sort_by { |base, _| -base.length }
      end

      def marked?(text)
        @replacements.any? { |base, _| text.to_s.include?(base) }
      end

      def url(value)
        matches =
          @replacements.select do |base, _|
            value.start_with?(base) && [nil, "/", "?", "#"].include?(value[base.length])
          end
        return value if matches.empty?
        longest = matches.first.first.length
        matches.select! { |base, _| base.length == longest }
        destinations = matches.map(&:last).uniq
        if destinations.size != 1 || destinations.first.blank?
          raise Unresolved, "No unambiguous destination for #{matches.first.first}"
        end
        destinations.first + value[matches.first.first.length..]
      end

      def html(text)
        return text unless marked?(text)
        fragment = Nokogiri::HTML5.fragment(text)
        changed = false
        fragment
          .css("*")
          .each do |element|
            next if element.ancestors.any? { |ancestor| %w[code pre].include?(ancestor.name) }
            URL_ATTRIBUTES.each do |attribute|
              next unless (original = element[attribute])
              replacement = url(original)
              if replacement != original
                element[attribute] = replacement
                changed = true
              end
            end
            if (original = element["srcset"])
              replacement =
                original.gsub(/(?:\A|(?<=,))\s*([^\s,]+)/) do |match|
                  match.sub(Regexp.last_match(1), url(Regexp.last_match(1)))
                end
              if replacement != original
                element["srcset"] = replacement
                changed = true
              end
            end
          end
        changed ? fragment.to_html : text
      end

      def raw(text)
        return text unless marked?(text)
        # Protect fenced and inline code before replacing Markdown destinations.
        text
          .split(%r{(```.*?```|~~~.*?~~~|`+[^`]*`+|<pre\b.*?</pre>|<code\b.*?</code>)}mi)
          .each_with_index
          .map do |part, index|
            next part if index.odd?
            part.gsub(
              %r{(\]\(\s*<?|^\s{0,3}\[[^\]\n]+\]:\s*<?|(?:href|src|poster)=["'])(/(?!/)[^\s"'<>\)]*)|https?://[^\s<>"'\)]+|//[^\s<>"'\)]+},
            ) do |match|
              prefix, relative_url = Regexp.last_match.captures
              relative_url ? prefix + url(relative_url) : url(match)
            end
          end
          .join
      end
    end
  end
end
