# frozen_string_literal: true

module DiscourseEvents
  module GroupTimezones
    class Extractor
      class << self
        def update(post)
          groups = []

          Nokogiri
            .HTML(post.cooked)
            .css("div.group-timezones")
            .map do |group_timezones|
              group_timezones.attributes.values.each do |attribute|
                if attribute.name == "data-group"
                  group_name = CGI.escapeHTML(attribute.value || "")
                  groups << group_name if group_name.present?
                end
              end
            end

          post.group_timezones = groups.present? ? { groups: groups } : nil
          post.save_custom_fields
        end
      end
    end
  end
end
