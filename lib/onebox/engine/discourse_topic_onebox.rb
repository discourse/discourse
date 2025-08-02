# frozen_string_literal: true

module Onebox
  module Engine
    class DiscourseTopicOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      matches_regexp(%r{/t/.*(/\d+)?})

      def data
        @data ||= {
          categories: categories,
          link: link,
          article_published_time: published_time.strftime("%-d %b %y"),
          article_published_time_title: published_time.strftime("%I:%M%p - %d %B %Y"),
          domain: html_entities.decode(raw[:site_name].truncate(80, separator: " ")),
          description: html_entities.decode(raw[:description].truncate(250, separator: " ")),
          title: html_entities.decode(raw[:title].truncate(80, separator: " ")),
          image: image,
          render_tags?: render_tags?,
          render_category_block?: render_category_block?,
        }.reverse_merge(raw)
      end
      alias verified_data data

      private

      def categories
        Array
          .wrap(raw[:article_sections])
          .map
          .with_index { |name, index| { name: name, color: raw[:article_section_colors][index] } }
      end

      def published_time
        @published_time ||= Time.parse(raw[:published_time])
      end

      def html_entities
        @html_entities ||= HTMLEntities.new
      end

      def image
        image = Onebox::Helpers.get_absolute_image_url(raw[:image], @url)
        Onebox::Helpers.normalize_url_for_output(html_entities.decode(image))
      end

      def render_tags?
        raw[:article_tags].present?
      end

      def render_category_block?
        render_tags? || categories.present?
      end
    end
  end
end
