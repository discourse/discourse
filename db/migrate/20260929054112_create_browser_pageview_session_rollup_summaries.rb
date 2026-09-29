# frozen_string_literal: true

class CreateBrowserPageviewSessionRollupSummaries < ActiveRecord::Migration[8.1]
  def up
    create_table :browser_pageview_session_rollup_summaries, id: false do |t|
      t.string :session_id, limit: 32, null: false, primary_key: true
      t.datetime :first_pageview_at
      t.bigint :pageview_count, null: false, default: 0
      t.boolean :logged_in, null: false, default: false
      t.boolean :likely_crawler, null: false, default: false
      t.bigint :engaged_seconds, null: false, default: 0
      t.bigint :dirty_generation, null: false, default: 1
      t.bigint :refreshed_generation, null: false, default: 0
    end
    add_index :browser_pageview_session_rollup_summaries, :first_pageview_at

    create_table :browser_pageview_session_rollup_repair_dates, id: false do |t|
      t.date :date, null: false, primary_key: true
    end

    create_table :browser_pageview_session_rollup_statuses do |t|
      t.integer :version, null: false
      t.datetime :initialized_at, null: false
    end

    execute <<~SQL
      CREATE SCHEMA IF NOT EXISTS discourse_functions;

      CREATE OR REPLACE FUNCTION discourse_functions.mark_browser_pageview_session_rollup_dirty(session_ids text[])
      RETURNS void LANGUAGE sql AS $$
        INSERT INTO browser_pageview_session_rollup_summaries (session_id)
        SELECT DISTINCT session_id
        FROM unnest(session_ids) AS session_id
        WHERE session_id IS NOT NULL
        ON CONFLICT (session_id) DO UPDATE
        SET dirty_generation = browser_pageview_session_rollup_summaries.dirty_generation + 1
      $$;

      CREATE OR REPLACE FUNCTION discourse_functions.mark_browser_pageview_event_insert()
      RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM discourse_functions.mark_browser_pageview_session_rollup_dirty(
          ARRAY(SELECT DISTINCT session_id::text FROM new_rows)
        );
        RETURN NULL;
      END;
      $$;

      CREATE OR REPLACE FUNCTION discourse_functions.mark_browser_pageview_event_update()
      RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM discourse_functions.mark_browser_pageview_session_rollup_dirty(
          ARRAY(
            SELECT old_rows.session_id::text
            FROM old_rows JOIN new_rows USING (id)
            WHERE (old_rows.session_id, old_rows.created_at, old_rows.user_id, old_rows.score)
              IS DISTINCT FROM
              (new_rows.session_id, new_rows.created_at, new_rows.user_id, new_rows.score)
            UNION
            SELECT new_rows.session_id::text
            FROM old_rows JOIN new_rows USING (id)
            WHERE (old_rows.session_id, old_rows.created_at, old_rows.user_id, old_rows.score)
              IS DISTINCT FROM
              (new_rows.session_id, new_rows.created_at, new_rows.user_id, new_rows.score)
          )
        );
        RETURN NULL;
      END;
      $$;

      CREATE OR REPLACE FUNCTION discourse_functions.mark_browser_pageview_event_delete()
      RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM discourse_functions.mark_browser_pageview_session_rollup_dirty(
          ARRAY(
            SELECT DISTINCT session_id::text
            FROM old_rows
            WHERE created_at >= CURRENT_DATE - INTERVAL '3 days'
          )
        );
        RETURN NULL;
      END;
      $$;

      CREATE OR REPLACE FUNCTION discourse_functions.mark_browser_pageview_engagement_insert()
      RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM discourse_functions.mark_browser_pageview_session_rollup_dirty(
          ARRAY(SELECT DISTINCT session_id::text FROM new_rows)
        );
        RETURN NULL;
      END;
      $$;

      CREATE OR REPLACE FUNCTION discourse_functions.mark_browser_pageview_engagement_update()
      RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM discourse_functions.mark_browser_pageview_session_rollup_dirty(
          ARRAY(
            SELECT old_rows.session_id::text
            FROM old_rows JOIN new_rows USING (id)
            WHERE (old_rows.session_id, old_rows.engaged_seconds)
              IS DISTINCT FROM (new_rows.session_id, new_rows.engaged_seconds)
            UNION
            SELECT new_rows.session_id::text
            FROM old_rows JOIN new_rows USING (id)
            WHERE (old_rows.session_id, old_rows.engaged_seconds)
              IS DISTINCT FROM (new_rows.session_id, new_rows.engaged_seconds)
          )
        );
        RETURN NULL;
      END;
      $$;

      CREATE OR REPLACE FUNCTION discourse_functions.mark_browser_pageview_engagement_delete()
      RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        PERFORM discourse_functions.mark_browser_pageview_session_rollup_dirty(
          ARRAY(
            SELECT DISTINCT session_id::text
            FROM old_rows
            WHERE created_at >= CURRENT_DATE - INTERVAL '3 days'
          )
        );
        RETURN NULL;
      END;
      $$;

      CREATE TRIGGER browser_pageview_event_rollup_insert
      AFTER INSERT ON browser_pageview_events
      REFERENCING NEW TABLE AS new_rows
      FOR EACH STATEMENT EXECUTE FUNCTION discourse_functions.mark_browser_pageview_event_insert();

      CREATE TRIGGER browser_pageview_event_rollup_update
      AFTER UPDATE ON browser_pageview_events
      REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
      FOR EACH STATEMENT EXECUTE FUNCTION discourse_functions.mark_browser_pageview_event_update();

      CREATE TRIGGER browser_pageview_event_rollup_delete
      AFTER DELETE ON browser_pageview_events
      REFERENCING OLD TABLE AS old_rows
      FOR EACH STATEMENT EXECUTE FUNCTION discourse_functions.mark_browser_pageview_event_delete();

      CREATE TRIGGER browser_pageview_engagement_rollup_insert
      AFTER INSERT ON browser_pageview_session_engagements
      REFERENCING NEW TABLE AS new_rows
      FOR EACH STATEMENT EXECUTE FUNCTION discourse_functions.mark_browser_pageview_engagement_insert();

      CREATE TRIGGER browser_pageview_engagement_rollup_update
      AFTER UPDATE ON browser_pageview_session_engagements
      REFERENCING OLD TABLE AS old_rows NEW TABLE AS new_rows
      FOR EACH STATEMENT EXECUTE FUNCTION discourse_functions.mark_browser_pageview_engagement_update();

      CREATE TRIGGER browser_pageview_engagement_rollup_delete
      AFTER DELETE ON browser_pageview_session_engagements
      REFERENCING OLD TABLE AS old_rows
      FOR EACH STATEMENT EXECUTE FUNCTION discourse_functions.mark_browser_pageview_engagement_delete();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER browser_pageview_event_rollup_insert ON browser_pageview_events;
      DROP TRIGGER browser_pageview_event_rollup_update ON browser_pageview_events;
      DROP TRIGGER browser_pageview_event_rollup_delete ON browser_pageview_events;
      DROP TRIGGER browser_pageview_engagement_rollup_insert ON browser_pageview_session_engagements;
      DROP TRIGGER browser_pageview_engagement_rollup_update ON browser_pageview_session_engagements;
      DROP TRIGGER browser_pageview_engagement_rollup_delete ON browser_pageview_session_engagements;
      DROP FUNCTION discourse_functions.mark_browser_pageview_event_insert();
      DROP FUNCTION discourse_functions.mark_browser_pageview_event_update();
      DROP FUNCTION discourse_functions.mark_browser_pageview_event_delete();
      DROP FUNCTION discourse_functions.mark_browser_pageview_engagement_insert();
      DROP FUNCTION discourse_functions.mark_browser_pageview_engagement_update();
      DROP FUNCTION discourse_functions.mark_browser_pageview_engagement_delete();
      DROP FUNCTION discourse_functions.mark_browser_pageview_session_rollup_dirty(text[]);
    SQL

    drop_table :browser_pageview_session_rollup_statuses
    drop_table :browser_pageview_session_rollup_repair_dates
    drop_table :browser_pageview_session_rollup_summaries
  end
end
