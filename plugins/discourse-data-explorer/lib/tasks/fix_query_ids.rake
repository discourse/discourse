# frozen_string_literal: true

desc "Fix query IDs to match the old ones used in the plugin store (q:id)"
task "data_explorer:fix_query_ids" => :environment do
  ActiveRecord::Base.transaction do
    # Only queries with unique title can be fixed
    movements = DB.query <<~SQL
    SELECT deq.id AS from, (replace(plugin_store_rows.key, 'q:',''))::integer AS to
    FROM plugin_store_rows
    INNER JOIN data_explorer_queries deq ON deq.name = plugin_store_rows.value::json->>'name'
    WHERE
      (replace(plugin_store_rows.key, 'q:',''))::integer != deq.id AND
      plugin_store_rows.plugin_name = 'discourse-data-explorer' AND
      plugin_store_rows.type_name = 'JSON' AND
      (SELECT COUNT(*) from data_explorer_queries deq2 WHERE deq.name = deq2.name) = 1
    SQL

    if movements.present?
      # If there are new queries, they still may have conflict
      # We just want to move their ids to safe space and we will not move them back
      additional_conflicts =
        DB.query(<<~SQL, from: movements.map { |m| m.from }, to: movements.map { |m| m.to })
        SELECT id FROM data_explorer_queries
        WHERE id IN (:to)
        AND id NOT IN (:from)
      SQL
      additional_conflicts = additional_conflicts.map(&:id)

      # Create temporary tables
      DB.exec <<~SQL
        CREATE TEMPORARY TABLE tmp_data_explorer_queries(
          id INTEGER PRIMARY KEY,
          name VARCHAR,
          description TEXT,
          sql TEXT,
          user_id INTEGER,
          last_run_at TIMESTAMP,
          hidden BOOLEAN,
          created_at TIMESTAMP,
          updated_at TIMESTAMP
        ) ON COMMIT DROP
      SQL

      DB.exec <<-SQL
        CREATE TEMPORARY TABLE tmp_data_explorer_query_groups(
          id INTEGER PRIMARY KEY,
          query_id INTEGER,
          group_id INTEGER
        ) ON COMMIT DROP
      SQL

      movements.each do |movement|
        # insert movements to temporary tables
        DB.exec <<-SQL
          INSERT INTO tmp_data_explorer_queries(id, name, description, sql, user_id, last_run_at, hidden, created_at, updated_at)
          SELECT #{movement.to}, name, description, sql, user_id, last_run_at, hidden, created_at, updated_at
          FROM data_explorer_queries
          WHERE id = #{movement.from}
        SQL

        DB.exec <<-SQL
          INSERT INTO tmp_data_explorer_query_groups(id, query_id, group_id)
          SELECT id, #{movement.to}, group_id
          FROM data_explorer_query_groups
          WHERE query_id = #{movement.from}
        SQL
      end

      # insert rest to temporary tables
      already_moved_ids = movements.map(&:from) | additional_conflicts
      DB.exec(<<-SQL, already_moved_ids: already_moved_ids)
        INSERT INTO tmp_data_explorer_queries(id, name, description, sql, user_id, last_run_at, hidden, created_at, updated_at)
        SELECT id, name, description, sql, user_id, last_run_at, hidden, created_at, updated_at
        FROM data_explorer_queries
        WHERE id NOT IN (:already_moved_ids)
      SQL

      DB.exec(<<-SQL, already_moved_ids: already_moved_ids)
        INSERT INTO tmp_data_explorer_query_groups(id, query_id, group_id)
        SELECT id, query_id, group_id
        FROM data_explorer_query_groups
        WHERE query_id NOT IN (:already_moved_ids)
      SQL

      # insert additional_conflicts to temporary tables
      new_id =
        DB.query("select greatest(max(id), 1) from tmp_data_explorer_queries").first.greatest + 1
      additional_conflicts.each do |conflict_id|
        DB.exec <<-SQL
          INSERT INTO tmp_data_explorer_queries(id, name, description, sql, user_id, last_run_at, hidden, created_at, updated_at)
          SELECT #{new_id}, name, description, sql, user_id, last_run_at, hidden, created_at, updated_at
          FROM data_explorer_queries
          WHERE id = #{conflict_id}
        SQL

        DB.exec <<~SQL
          INSERT INTO tmp_data_explorer_query_groups(id, query_id, group_id)
          SELECT id, #{new_id}, group_id
          FROM data_explorer_query_groups
          WHERE query_id = #{conflict_id}
        SQL

        new_id = new_id + 1
      end

      # clear original tables and copy data from temporary tables
      DB.exec("DELETE FROM data_explorer_queries")
      DB.exec("INSERT INTO data_explorer_queries SELECT * FROM tmp_data_explorer_queries")

      DB.exec("DELETE FROM data_explorer_query_groups")
      DB.exec("INSERT INTO data_explorer_query_groups SELECT * FROM tmp_data_explorer_query_groups")

      # Update id sequences
      DB.exec <<~SQL
        SELECT
          setval(
            pg_get_serial_sequence('data_explorer_queries', 'id'),
            (select greatest(max(id), 1) from data_explorer_queries)
          );
      SQL

      DB.exec <<~SQL
        SELECT
          setval(
            pg_get_serial_sequence('data_explorer_query_groups', 'id'),
            (select greatest(max(id), 1) from data_explorer_query_groups)
          );
      SQL
    end
  end
end
