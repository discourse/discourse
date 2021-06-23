# frozen_string_literal: true

class MigratePollsData < ActiveRecord::Migration[5.2]
  def escape(text)
    PG::Connection.escape_string(text)
  end

  POLL_TYPES ||= {
    "regular" => 0,
    "multiple" => 1,
    "number" => 2,
  }

  PG_INTEGER_MAX ||= 2_147_483_647

  def up
    # Ensure we don't have duplicate polls
    DB.exec <<~SQL
      WITH duplicates AS (
        SELECT id, row_number() OVER (PARTITION BY post_id) r
          FROM post_custom_fields
         WHERE name = 'polls'
         ORDER BY created_at
      )
      DELETE FROM post_custom_fields
       WHERE id IN (SELECT id FROM duplicates WHERE r > 1)
    SQL

    # Ensure we don't have duplicate votes
    DB.exec <<~SQL
      WITH duplicates AS (
        SELECT id, row_number() OVER (PARTITION BY post_id) r
          FROM post_custom_fields
         WHERE name = 'polls-votes'
         ORDER BY created_at
      )
      DELETE FROM post_custom_fields
       WHERE id IN (SELECT id FROM duplicates WHERE r > 1)
    SQL

    # Ensure we have votes records
    DB.exec <<~SQL
      INSERT INTO post_custom_fields (post_id, name, value, created_at, updated_at)
      SELECT post_id, 'polls-votes', '{}', created_at, updated_at
        FROM post_custom_fields
       WHERE name = 'polls'
         AND post_id NOT IN (SELECT post_id FROM post_custom_fields WHERE name = 'polls-votes')
    SQL

    sql = <<~SQL
      SELECT polls.post_id
           , polls.created_at
           , polls.updated_at
           , polls.value::json "polls"
           , votes.value::json "votes"
        FROM post_custom_fields polls
        JOIN post_custom_fields votes
          ON polls.post_id = votes.post_id
       WHERE polls.name = 'polls'
         AND votes.name = 'polls-votes'
       ORDER BY polls.post_id
    SQL

    DB.query(sql).each do |r|
      # for some reasons, polls or votes might be an array
      r.polls = r.polls[0] if Array === r.polls && r.polls.size > 0
      r.votes = r.votes[0] if Array === r.votes && r.votes.size > 0

      existing_user_ids = User.where(id: r.votes.keys).pluck(:id).to_set

      # Poll votes are stored in a JSON object with the following hierarchy
      #   user_id -> poll_name -> options
      # Since we're iterating over polls, we need to change the hierarchy to
      #   poll_name -> user_id -> options

      votes = {}
      r.votes.each do |user_id, user_votes|
        # don't migrate votes from deleted/non-existing users
        next unless existing_user_ids.include?(user_id.to_i)

        user_votes.each do |poll_name, options|
          votes[poll_name] ||= {}
          votes[poll_name][user_id] = options
        end
      end

      r.polls.values.each do |poll|
        name = escape(poll["name"].presence || "poll")
        type = POLL_TYPES[(poll["type"].presence || "")[/(regular|multiple|number)/, 1] || "regular"]
        status = poll["status"] == "open" ? 0 : 1
        visibility = poll["public"] == "true" ? 1 : 0
        close_at = (Time.zone.parse(poll["close"]) rescue nil)
        min = poll["min"].to_i.clamp(0, PG_INTEGER_MAX)
        max = poll["max"].to_i.clamp(0, PG_INTEGER_MAX)
        step = poll["step"].to_i.clamp(0, max)
        anonymous_voters = poll["anonymous_voters"].to_i.clamp(0, PG_INTEGER_MAX)

        next if DB.query_single("SELECT COUNT(*) FROM polls WHERE post_id = ? AND name = ? LIMIT 1", r.post_id, name).first > 0

        poll_id = execute(<<~SQL
          INSERT INTO polls (
            post_id,
            name,
            type,
            status,
            visibility,
            close_at,
            min,
            max,
            step,
            anonymous_voters,
            created_at,
            updated_at
          ) VALUES (
            #{r.post_id},
            '#{name}',
            #{type},
            #{status},
            #{visibility},
            #{close_at ? "'#{close_at}'" : "NULL"},
            #{min > 0 ? min : "NULL"},
            #{max > min ? max : "NULL"},
            #{step > 0 ? step : "NULL"},
            #{anonymous_voters > 0 ? anonymous_voters : "NULL"},
            '#{r.created_at}',
            '#{r.updated_at}'
          ) RETURNING id
        SQL
        )[0]["id"]

        option_ids = Hash[*DB.query_single(<<~SQL
          INSERT INTO poll_options
            (poll_id, digest, html, anonymous_votes, created_at, updated_at)
          VALUES
            #{poll["options"].map { |option|
              "(#{poll_id}, '#{escape(option["id"])}', '#{escape(option["html"].strip)}', #{option["anonymous_votes"].to_i}, '#{r.created_at}', '#{r.updated_at}')" }.join(",")
            }
          RETURNING digest, id
        SQL
        )]

        if votes[name].present?
          poll_votes = votes[name].map do |user_id, options|
            options
              .select { |o| option_ids.has_key?(o) }
              .map { |o| "(#{poll_id}, #{option_ids[o]}, #{user_id.to_i}, '#{r.created_at}', '#{r.updated_at}')" }
          end

          poll_votes.flatten!
          poll_votes.uniq!

          if poll_votes.present?
            execute <<~SQL
              INSERT INTO poll_votes (poll_id, poll_option_id, user_id, created_at, updated_at)
              VALUES #{poll_votes.join(",")}
            SQL
          end
        end
      end
    end

    execute <<~SQL
      INSERT INTO post_custom_fields (name, value, post_id, created_at, updated_at)
      SELECT 'has_polls', 't', post_id, MIN(created_at), MIN(updated_at)
        FROM polls
       GROUP BY post_id
    SQL
  end

  def down
  end
end
