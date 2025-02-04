# frozen_string_literal: true

# name: discourse-local-dates
# about: Display a date in your local timezone
# version: 0.1
# author: Joffrey Jaffeux

hide_plugin

register_asset "stylesheets/common/discourse-local-dates.scss"
register_asset "moment.js", :vendored_core_pretty_text
register_asset "moment-timezone.js", :vendored_core_pretty_text

enabled_site_setting :discourse_local_dates_enabled

after_initialize do
  module ::DiscourseLocalDates
    PLUGIN_NAME = "discourse-local-dates".freeze
    POST_CUSTOM_FIELD = "local_dates".freeze
  end

  require_relative "lib/discourse_local_dates/engine"

  register_post_custom_field_type(DiscourseLocalDates::POST_CUSTOM_FIELD, :json)

  on(:before_post_process_cooked) do |doc, post|
    dates = []

    doc
      .css("span.discourse-local-date")
      .map do |cooked_date|
        next if cooked_date.ancestors("aside").length > 0
        date = {}
        cooked_date.attributes.values.each do |attribute|
          data_name = attribute.name&.gsub("data-", "")
          if data_name && %w[date time timezone recurring].include?(data_name)
            unless attribute.value == "undefined"
              date[data_name] = CGI.escapeHTML(attribute.value || "")
            end
          end
        end
        dates << date
      end

    if dates.present?
      post.custom_fields[DiscourseLocalDates::POST_CUSTOM_FIELD] = dates
      post.save_custom_fields
    elsif !post.custom_fields[DiscourseLocalDates::POST_CUSTOM_FIELD].nil?
      post.custom_fields.delete(DiscourseLocalDates::POST_CUSTOM_FIELD)
      post.save_custom_fields
    end
  end

  add_to_class(:post, :local_dates) { custom_fields[DiscourseLocalDates::POST_CUSTOM_FIELD] || [] }

  on(:reduce_excerpt) do |fragment, post|
    fragment
      .css(".discourse-local-date")
      .each { |container| container.content = "#{container.content} (UTC)" }
  end

  on(:reduce_cooked) do |fragment|
    fragment
      .css(".discourse-local-date")
      .each do |container|
        if container.attributes["data-email-preview"]
          preview = container.attributes["data-email-preview"].value
          container.content = preview
        end
      end
  end
end
