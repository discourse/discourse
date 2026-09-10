# frozen_string_literal: true

class SetBrowserPageviewEventSourceDefaultToBeacon < ActiveRecord::Migration[8.0]
  def up
    change_column_default :browser_pageview_events, :source, from: 1, to: 2

    execute <<~SQL
      CREATE SCHEMA IF NOT EXISTS discourse_functions;

      CREATE FUNCTION discourse_functions.skip_piggyback_browser_pageview_events()
      RETURNS trigger AS $$
      BEGIN
        IF NEW.source = 1 THEN
          RETURN NULL;
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;

      CREATE TRIGGER skip_piggyback_browser_pageview_events
      BEFORE INSERT OR UPDATE OF source ON browser_pageview_events
      FOR EACH ROW WHEN (NEW.source IN (1, 2))
      EXECUTE FUNCTION discourse_functions.skip_piggyback_browser_pageview_events();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER skip_piggyback_browser_pageview_events ON browser_pageview_events;
      DROP FUNCTION discourse_functions.skip_piggyback_browser_pageview_events();
    SQL
    change_column_default :browser_pageview_events, :source, from: 2, to: 1
  end
end
