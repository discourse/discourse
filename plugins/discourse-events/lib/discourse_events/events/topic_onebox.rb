# frozen_string_literal: true

module DiscourseEvents
  module Events
    # Swaps the quote of core's internal topic onebox for the event's details
    class TopicOnebox
      TEMPLATE = File.read(File.expand_path("../../onebox/templates/event.mustache", __dir__))

      def self.args(args, post, opts)
        return args if !SiteSetting.discourse_post_event_enabled || post.post_number != 1

        event = Event.visible.includes(:event_dates).find_by(id: post.id)
        return args if !event || !event.starts_at

        I18n.with_locale(locale(opts[:locale])) do
          name = event.name.presence
          # the onebox header already links the topic title
          name = nil if name == post.topic.title

          args.merge(
            quote:
              Mustache.render(
                TEMPLATE,
                name: name && emoji_html(name),
                summary: Excerpt.t("summary", summary: dates(event)),
                location: event.location.presence && emoji_html(Parser.inline_text(event.location)),
              ),
          )
        end
      end

      # a localization's locale isn't validated, so it may not be switchable
      def self.locale(locale)
        locale = LocaleNormalizer.normalize_to_i18n(locale)
        I18n.locale_available?(locale) ? locale : I18n.locale
      end

      def self.emoji_html(text)
        PrettyText.unescape_emoji(CGI.escapeHTML(text))
      end

      def self.dates(event)
        timezone = event.timezone.presence || Event::DEFAULT_TIMEZONE
        timezone = Event::DEFAULT_TIMEZONE if ActiveSupport::TimeZone[timezone].nil?

        Excerpt.format_dates(
          in_zone(event.starts_at, timezone, event.all_day),
          in_zone(event.ends_at, timezone, event.all_day),
          all_day: event.all_day,
          timezone: timezone,
        )
      end

      # all-day dates are stored in UTC (midnight start, end-of-day end)
      def self.in_zone(time, timezone, all_day)
        return if time.nil?
        all_day ? time.utc : time.in_time_zone(timezone)
      end

      private_class_method :locale, :emoji_html, :dates, :in_zone
    end
  end
end
