# frozen_string_literal: true

class MoveDataToEventDates < ActiveRecord::Migration[6.0]
  VALID_OPTIONS = [:start, :end, :status, :"allowed-groups", :url, :name, :reminders, :recurrence]

  def extract_events(post)
    valid_options = VALID_OPTIONS.map { |o| "data-#{o}" }

    valid_custom_fields = []

    allowed_custom_fields =
      DB
        .query(
          "SELECT * FROM site_settings WHERE name = 'discourse_post_event_allowed_custom_fields' LIMIT 1",
        )
        .first
        &.value || ""
    allowed_custom_fields
      .split("|")
      .each do |setting|
        valid_custom_fields << {
          original: "data-#{setting}",
          normalized: "data-#{setting.gsub(/_/, "-")}",
        }
      end

    Nokogiri
      .HTML(post.cooked)
      .css("div.discourse-post-event")
      .map do |doc|
        event = nil
        doc.attributes.values.each do |attribute|
          name = attribute.name
          value = attribute.value

          if value && valid_options.include?(name)
            event ||= {}
            event[name.sub("data-", "").to_sym] = CGI.escapeHTML(value)
          end

          valid_custom_fields.each do |valid_custom_field|
            if value && valid_custom_field[:normalized] == name
              event ||= {}
              event[valid_custom_field[:original].sub("data-", "").to_sym] = CGI.escapeHTML(value)
            end
          end
        end
        event
      end
      .compact
  end

  def due_reminders(event)
    return [] if event.reminders.blank?
    event
      .reminders
      .split(",")
      .map do |reminder|
        value, unit = reminder.split(".")

        allowed = %w[years months weeks days hours minutes seconds]
        next if !allowed.include?(unit)
        date = event.original_starts_at - value.to_i.public_send(unit)
        { description: reminder, date: date }
      end
      .compact
      .select { |reminder| reminder[:date] <= Time.current }
      .sort_by { |reminder| reminder[:date] }
  end

  def up
    rename_column :discourse_post_event_events, :starts_at, :original_starts_at
    rename_column :discourse_post_event_events, :ends_at, :original_ends_at

    query = <<~SQL
      SELECT * FROM discourse_post_event_events
      WHERE original_ends_at IS NOT NULL
    SQL

    DB
      .query(query)
      .each do |event|
        post = DB.query("SELECT * FROM posts WHERE id = #{event.id}").first
        next if !post
        extracted_event = extract_events(post).first
        next if !extracted_event

        finished_at = (event.original_ends_at < Time.current) && event.original_ends_at
        event_will_start_sent_at = event.original_starts_at - 1.hours
        event_started_sent_at = event.original_starts_at
        reminder_counter = due_reminders(event).length

        DB.exec <<~SQL
        INSERT INTO discourse_calendar_post_event_dates(event_id, starts_at, ends_at, event_will_start_sent_at, event_started_sent_at, #{finished_at ? "finished_at ," : ""} reminder_counter, created_at, updated_at)
        VALUES (#{event.id},
        '#{event.original_starts_at}',
        '#{event.original_ends_at}',
        '#{event_will_start_sent_at}',
        '#{event_started_sent_at}',
        #{finished_at ? ("'" + finished_at.to_s + "'" + ", ") : ""}
        #{reminder_counter},
        now(),
        now())
      SQL
        DB.exec <<~SQL
        UPDATE discourse_post_event_events
        SET original_starts_at = '#{extracted_event[:start]}', original_ends_at = '#{extracted_event[:end]}'
        WHERE id = #{event.id}
      SQL
      end

    begin
      Jobs.cancel_scheduled_job(:discourse_post_event_send_reminder)
    rescue StandardError
      nil
    end
    begin
      Jobs.cancel_scheduled_job(:discourse_post_event_event_started)
    rescue StandardError
      nil
    end
    begin
      Jobs.cancel_scheduled_job(:discourse_post_event_event_will_start)
    rescue StandardError
      nil
    end
    begin
      Jobs.cancel_scheduled_job(:discourse_post_event_event_ended)
    rescue StandardError
      nil
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
