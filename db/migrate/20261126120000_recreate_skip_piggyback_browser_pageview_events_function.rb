# frozen_string_literal: true

class RecreateSkipPiggybackBrowserPageviewEventsFunction < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
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
