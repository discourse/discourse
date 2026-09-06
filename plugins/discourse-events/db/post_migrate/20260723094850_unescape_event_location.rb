# frozen_string_literal: true

class UnescapeEventLocation < ActiveRecord::Migration[8.0]
  def up
    DB
      .query("SELECT id, location FROM discourse_post_event_events WHERE location LIKE '%&%'")
      .each do |event|
        unescaped = CGI.unescapeHTML(CGI.unescapeHTML(event.location))
        next if unescaped == event.location

        DB.exec(
          "UPDATE discourse_post_event_events SET location = :location WHERE id = :id",
          location: unescaped,
          id: event.id,
        )
      end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
