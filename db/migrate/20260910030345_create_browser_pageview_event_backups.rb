# frozen_string_literal: true

class CreateBrowserPageviewEventBackups < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      CREATE TABLE browser_pageview_events_backup (LIKE browser_pageview_events);
      ALTER TABLE browser_pageview_events_backup ADD PRIMARY KEY (id);

      CREATE TABLE browser_pageview_event_scores_backup (LIKE browser_pageview_event_scores);
      ALTER TABLE browser_pageview_event_scores_backup ADD PRIMARY KEY (id);

      CREATE OR REPLACE FUNCTION discourse_functions.skip_piggyback_browser_pageview_events()
      RETURNS trigger AS $$
      BEGIN
        IF NEW.source = 1 THEN
          RETURN NULL;
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
