# frozen_string_literal: true

module DiscoursePostEvent
  class EmailRenderer
    RECURRENCE_ORDINALS = %w[first second third fourth]

    def self.render(event_node, post)
      new(event_node, post).to_html
    end

    def initialize(event_node, post)
      @event_node = event_node
      @post = post
      @event = DiscoursePostEvent::Event.includes(:image_upload, :event_dates).find_by(id: post.id)
      @starts_at = event_node["data-start"]
      @timezone = event_node["data-timezone"] || "UTC"
      @all_day = event_node["data-all-day"] == "true"
    end

    def to_html
      rows = [
        image_row,
        name_row,
        status_and_creator_row,
        dates_row,
        recurrence_row,
        location_row,
        url_row,
        invitees_row,
        description_row,
      ].join

      <<~HTML
        <table cellspacing="0" cellpadding="0" border="0" style="border: 1px solid #dedede; margin-bottom: 10px; width: 100%;">
          #{rows}
        </table>
      HTML
    end

    private

    attr_reader :event_node, :post, :starts_at, :timezone

    def image_row
      return "" if @event&.image_upload_id.blank?

      image_url = UrlHelper.absolute(@event.image_upload.url)
      <<~HTML
        <tr>
          <td style="padding: 0;">
            <img src="#{CGI.escape_html(image_url)}" style="width: 100%; max-height: 400px; object-fit: cover; display: block;" />
          </td>
        </tr>
      HTML
    end

    def name_row
      name = event_node["data-name"] || post.topic.title
      name = CGI.escape_html(Emoji.gsub_emoji_to_unicode(name))
      <<~HTML
        <tr>
          <td style="padding: 12px;">
            <a href="#{post.full_url}" style="font-weight: bold; font-size: 1.1em;">#{name}</a>
          </td>
        </tr>
      HTML
    end

    def muted_row(content)
      return "" if content.blank?

      <<~HTML
        <tr>
          <td style="padding: 0 12px 12px; color: #666;">#{content}</td>
        </tr>
      HTML
    end

    def status_and_creator_row
      muted_row([status_label, creator_label].compact.join(" · "))
    end

    def dates_row
      muted_row(CGI.escape_html(dates))
    end

    def recurrence_row
      label = recurrence_label
      muted_row(label && CGI.escape_html(label))
    end

    def location_row
      location = event_node["data-location"]
      return "" if location.blank?

      muted_row(PrettyText.cook(location))
    end

    def url_row
      url = event_node["data-url"].to_s.strip
      return "" if url.blank?

      href = web_url?(url) ? url : "https://#{url}"
      <<~HTML
        <tr>
          <td style="padding: 0 12px 12px;"><a href="#{CGI.escape_html(href)}">#{CGI.escape_html(url)}</a></td>
        </tr>
      HTML
    end

    def web_url?(url)
      url.match?(%r{\A(?:https?://|mailto:)}i)
    end

    def invitees_row
      return "" if @event.nil? || @event.standalone? || @event.minimal

      muted_row(
        CGI.escape_html(card_t("models.invitee.status.going_count", count: @event.going_count)),
      )
    end

    def description_row
      return "" if @event&.description.blank?

      muted_row(DiscoursePostEvent::EventParser.linkify_description(@event.description, post:))
    end

    def dates
      return "-" if @event&.expired? && @event.recurring?

      suffix = timezone_suffix
      formatted = "#{format_date(starts_at)}#{suffix}"

      ends_at = event_node["data-end"]
      formatted = "#{formatted} → #{format_date(ends_at)}#{suffix}" if ends_at

      formatted
    end

    def format_date(value)
      format = all_day? ? "%B %-d, %Y" : "%B %-d, %Y %-I:%M %p"
      DateTime.parse(value).strftime(format)
    rescue StandardError
      value
    end

    def timezone_suffix
      all_day? ? "" : " (#{timezone})"
    end

    def status_label
      return nil if @event.nil?
      return card_t("models.event.expired") if @event.expired?
      return card_t("models.event.closed") if @event.closed

      key =
        if @event.standalone?
          "standalone"
        elsif @event.private?
          "private"
        else
          "public"
        end
      card_t("models.event.status.#{key}.title")
    end

    def creator_label
      user = post.user
      return nil if user.nil?

      name = SiteSetting.enable_names? ? user.display_name : user.username
      "#{card_t("created_by")} #{CGI.escape_html(name)}"
    end

    def recurrence_label
      recurrence = @event&.recurrence
      return nil if recurrence.blank? || EventValidator::VALID_RECURRENCES.exclude?(recurrence)

      card_t("builder_modal.recurrence.#{recurrence}", **recurrence_context)
    rescue StandardError
      nil
    end

    def recurrence_context
      ref = recurrence_ref
      return {} if ref.nil?

      { weekday: ref.strftime("%A"), ordinal: recurrence_ordinal(ref) }
    end

    def recurrence_ref
      return Date.parse(starts_at) if all_day?

      zone = ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["UTC"]
      zone.parse(starts_at)
    rescue StandardError
      nil
    end

    def recurrence_ordinal(ref)
      day_of_month = ref.mday
      days_in_month = Date.new(ref.year, ref.month, -1).day
      is_last = day_of_month + 7 > days_in_month
      key = is_last ? "last" : RECURRENCE_ORDINALS[(day_of_month / 7.0).ceil - 1]
      card_t("builder_modal.recurrence.ordinals.#{key}")
    end

    def card_t(key, **options)
      I18n.t("js.discourse_post_event.#{key}", **options)
    end

    def all_day?
      @all_day
    end
  end
end
