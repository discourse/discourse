# frozen_string_literal: true

module DiscourseEvents
  module Events
    class Onebox
      TEMPLATE = File.read(File.expand_path("../../onebox/templates/event.mustache", __dir__))

      def self.args(args, post, opts)
        return args if !SiteSetting.discourse_post_event_enabled || post.post_number != 1

        event = Event.visible.includes(:event_dates).find_by(id: post.id)
        return args if !event || !event.starts_at

        I18n.with_locale(opts[:locale].presence || I18n.locale) do
          dates = format_date(event.starts_at, event)
          if event.ends_at
            dates =
              I18n.t(
                "discourse_post_event.event_excerpt.date_range",
                from: dates,
                to: format_date(event.ends_at, event),
              )
          end
          unless event.all_day
            dates =
              I18n.t(
                "discourse_post_event.event_excerpt.date_with_timezone",
                date: dates,
                timezone: event.timezone.presence || "UTC",
              )
          end

          args.merge(
            quote:
              Mustache.render(
                TEMPLATE,
                name: event.name.presence,
                dates: dates,
                location: event.location.presence && Parser.inline_text(event.location),
              ),
          )
        end
      end

      def self.format_date(date, event)
        format = event.all_day ? "date_format" : "datetime_format"
        date = date.in_time_zone(event.timezone.presence || "UTC") unless event.all_day
        I18n.l(date, format: I18n.t("discourse_post_event.event_excerpt.#{format}"))
      end
      private_class_method :format_date
    end
  end
end
