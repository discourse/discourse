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
      :livestream,
      :"max-attendees",
      :"all-day",
      :image,
    ]

    LEGACY_ESCAPED_ATTRS = %w[data-location]

    def self.extract_events(post)
      cooked = PrettyText.cook(post.raw, topic_id: post.topic_id, user_id: post.user_id)
      valid_options = valid_option_attributes

      valid_custom_fields =
        SiteSetting
          .discourse_post_event_allowed_custom_fields
          .split("|")
          .map do |setting|
            { original: "data-#{setting}", normalized: custom_field_data_attribute(setting) }
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
              value = CGI.unescapeHTML(value) if LEGACY_ESCAPED_ATTRS.include?(name)
              event[name.sub("data-", "").to_sym] = case name
              when "data-name", "data-url", "data-image", "data-location"
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
          event[:description] = to_markdown(doc) if event
          event
        end
        .compact
    end

    def self.valid_option_attributes
      VALID_OPTIONS.map { |option| "data-#{option}" }
    end

    def self.custom_field_data_attribute(setting)
      camelized = setting.downcase.gsub(/[-.]/, "_").gsub(/_(.)/) { $1.upcase }
      dasherized = camelized.gsub(/[A-Z]/) { |char| "-#{char.downcase}" }.sub(/\A-/, "")
      "data-#{dasherized}"
    end

    INLINE_MARKDOWN_FEATURES = %w[emoji linkify]
    INLINE_MARKDOWN_IT_RULES = %w[link linkify entity escape newline]
    INLINE_CACHE_VERSION = 2

    def self.cook_inline(text, post: nil)
      text = text.to_s
      add_nofollow = post.nil? || post.add_nofollow?

      Discourse
        .cache
        .fetch(
          "post-event-inline:#{INLINE_CACHE_VERSION}:#{Digest::SHA1.hexdigest(text)}:#{add_nofollow}",
          expires_in: 1.week,
        ) do
          cooked =
            PrettyText.cook(
              text,
              features_override: INLINE_MARKDOWN_FEATURES,
              markdown_it_rules: INLINE_MARKDOWN_IT_RULES,
              omit_nofollow: !add_nofollow,
            )
          fragment = Nokogiri::HTML5.fragment(cooked)
          content = fragment.children.reject(&:blank?)
          if content.length == 1 && content.first.name == "p"
            content.first.inner_html
          else
            fragment.to_html
          end
        end
    end

    def self.inline_text(text)
      cooked = cook_inline(text)
      PrettyText.excerpt(cooked, cooked.length, strip_links: true, text_entities: true)
    end

    def self.linkable_url?(url)
      url = url.to_s.downcase
      schemes = %w[http https mailto] | SiteSetting.allowed_href_schemes.split("|")
      schemes.any? { |scheme| url.start_with?("#{scheme}:") }
    end

    def self.to_markdown(node)
      fragment = node.dup
      fragment
        .css("img.emoji")
        .each { |img| img.replace(img.document.create_text_node(img["alt"].to_s)) }
      fragment
        .css("a[href]")
        .each do |a|
          href = a["href"].to_s
          next if !linkable_url?(href)
          markdown = a.text == href ? href : "[#{a.text}](#{href})"
          a.replace(a.document.create_text_node(markdown))
        end
      fragment.text.strip
    end
  end
end
