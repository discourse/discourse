# frozen_string_literal: true

module DiscoursePostEvent
  class EventParser
    VALID_OPTIONS = [
      :start,
      :end,
      :status,
      :"allowed-groups",
      :url,
      :location,
      :name,
      :reminders,
      :recurrence,
      :"recurrence-until",
      :timezone,
      :"show-local-time",
      :minimal,
      :closed,
      :"chat-enabled",
    ]

    def self.extract_events(post)
      cooked = PrettyText.cook(post.raw, topic_id: post.topic_id, user_id: post.user_id)
      valid_options = VALID_OPTIONS.map { |o| "data-#{o}" }

      valid_custom_fields = []
      SiteSetting
        .discourse_post_event_allowed_custom_fields
        .split("|")
        .each do |setting|
          valid_custom_fields << {
            original: "data-#{setting}",
            normalized: "data-#{setting.gsub(/_/, "-")}",
          }
        end

      Nokogiri
        .HTML(cooked)
        .css("div.discourse-post-event")
        .map do |doc|
          event = nil
          doc.attributes.values.each do |attribute|
            name = attribute.name
            value = attribute.value

            if value && valid_options.include?(name)
              event ||= {}
              event[name.sub("data-", "").to_sym] = if %w[data-name data-url].include?(name)
                value
              else
                CGI.escapeHTML(value)
              end
            end

            valid_custom_fields.each do |valid_custom_field|
              if value && valid_custom_field[:normalized] == name
                event ||= {}
                event[valid_custom_field[:original].sub("data-", "").to_sym] = CGI.escapeHTML(value)
              end
            end
          end
          event[:description] = doc.text.strip if event
          event
        end
        .compact
    end
  end
end
