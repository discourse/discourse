# frozen_string_literal: true

module Onebox
  module Engine
    class DiscourseTopicOnebox
      include Engine
      include StandardEmbed
      include LayoutSupport

      matches_regexp(%r{/t/.*(/\d+)?})

      def layout
        @layout ||= Layout.new(event? ? "discoursetopic_with_event" : self.class.onebox_name, data)
      end

      def data
        @data ||= {
          categories: categories,
          link: link,
          # The event date is shown in the body, so a post date in the header reads as a second event date
          article_published_time: (published_time.strftime("%-d %b %y") unless event?),
          article_published_time_title:
            (published_time.strftime("%I:%M%p - %d %B %Y") unless event?),
          domain: html_entities.decode(raw[:site_name].truncate(80, separator: " ")),
          description: description,
          is_event: event?,
          event_all_day: event_all_day?,
          event_date_day: event_date&.strftime("%-d"),
          event_date_month: event_date&.strftime("%b"),
          event_description: event_description,
          event_ends_at: raw[:event_ends_at],
          event_onebox_classes: event_onebox_classes,
          event_starts_at: raw[:event_starts_at],
          event_time: event_time,
          event_timezone: event_timezone,
          title: html_entities.decode(raw[:title].truncate(80, separator: " ")),
          image: image,
          render_tags?: render_tags?,
          render_category_block?: render_category_block?,
        }.reverse_merge(raw)
      end
      alias verified_data data

      private

      def description
        value = event? ? event_description : raw[:description]
        return if value.blank?

        html_entities.decode(value.to_s.truncate(250, separator: " "))
      end

      def event?
        raw[:event_starts_at].present?
      end

      def event_all_day?
        event? && ActiveModel::Type::Boolean.new.cast(raw[:event_all_day])
      end

      def event_date
        return unless event?

        if event_all_day?
          Date.iso8601(raw[:event_starts_at])
        else
          event_time_value(raw[:event_starts_at]).to_date
        end
      rescue ArgumentError
        nil
      end

      def event_description
        return unless event?

        raw[:event_description]
      end

      def event_has_banner_image?
        width, height = event_image_dimensions
        width.present? && width >= height
      end

      # Too far from 16:9 to crop without losing much of the image, so it's shown whole inside the banner
      def event_has_letterboxed_image?
        width, height = event_image_dimensions
        width.present? && width >= height && (width < height * 4 / 3 || width > height * 2)
      end

      def event_has_portrait_image?
        width, height = event_image_dimensions
        width.present? && height > width
      end

      def event_onebox_classes
        [
          "discourse-event-onebox",
          ("--banner-image" if event_has_banner_image?),
          ("--letterboxed-image" if event_has_letterboxed_image?),
          ("--portrait-image" if event_has_portrait_image?),
        ].compact.join(" ")
      end

      def event_image_dimensions
        width = raw[:event_image_width].to_f
        height = raw[:event_image_height].to_f
        return if !event? || raw[:event_image].blank? || !width.positive? || !height.positive?

        [width, height]
      end

      def event_time
        return unless event?
        return I18n.t("onebox.discourse.event_all_day") if event_all_day?

        starts_at = event_time_value(raw[:event_starts_at])
        ends_at = event_time_value(raw[:event_ends_at])

        time = starts_at.strftime("%-I:%M %p")
        time = "#{time} → #{ends_at.strftime("%-I:%M %p")}" if ends_at
        "#{time} (#{event_timezone})"
      rescue ArgumentError
        nil
      end

      def event_time_value(value)
        return if value.blank?

        Time.iso8601(value)
      end

      def event_timezone
        starts_at = event_time_value(raw[:event_starts_at])
        return "UTC" if starts_at.blank? || starts_at.utc_offset.zero?

        "UTC#{starts_at.formatted_offset}"
      rescue ArgumentError
        "UTC"
      end

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
        # Events only show their own image; the page's og:image can be a site-wide fallback like the logo
        url = event? ? raw[:event_image] : raw[:image]
        return if url.blank?

        image = Onebox::Helpers.get_absolute_image_url(url, @url)
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
