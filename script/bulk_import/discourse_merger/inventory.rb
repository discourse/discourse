# frozen_string_literal: true

require_relative "configuration"
require_relative "group_mapping"
require_relative "content_inventory"
require_relative "matched_avatars"
require_relative "reviewed_post_uploads"
require_relative "reviewed_revision_uploads"

module BulkImport::DiscourseMerge
  class Inventory
    CATEGORY_SQL =
      "SELECT id,name,parent_category_id,topic_id,read_restricted FROM categories ORDER BY id"

    def initialize(configuration, progress: nil)
      @configuration = configuration
      @progress = progress
    end

    def source_categories
      connect("source") do |connection|
        connection.exec(CATEGORY_SQL).to_a.index_by { |row| row.fetch("id").to_i }
      end
    end

    def connect(side, &block)
      require "pg"
      PG.connect(
        **@configuration.connection(side),
        connect_timeout: 5,
        options: "-c default_transaction_read_only=on",
        &block
      )
    rescue PG::Error => error
      raise Error,
            "Cannot read the #{side} PostgreSQL database; check merge.yml and the prepared database: #{error.message.strip}"
    end

    def capture(source_connection: nil, content: false)
      inventories = {}
      member_emails = {}
      source_members = {}
      %w[source destination].each do |side|
        @progress&.start("#{side} inventory")
        snapshot(side, source_connection) do |connection|
          result = {
            "database" => connection.exec("SELECT current_database()").getvalue(0, 0),
            "schema" =>
              connection.exec("SELECT max(version) FROM schema_migrations").getvalue(0, 0),
          }
          result["migrations"] = connection.exec(
            "SELECT version FROM schema_migrations ORDER BY version",
          ).column_values(0)
          result["login_required"] = connection
            .exec("SELECT value FROM site_settings WHERE name='login_required'")
            .first
            &.fetch("value") == "t"
          result["system_accounts"] = connection.exec(
            "SELECT id,username FROM users WHERE id IN (-1,-2) ORDER BY id",
          ).to_a
          result["database_identity"] = connection.exec(
            "SELECT current_database(), inet_server_addr()::text, inet_server_port(), (SELECT oid FROM pg_database WHERE datname=current_database()) AS database_oid",
          ).first
          tables = {
            "categories" => CATEGORY_SQL,
            "grants" =>
              "SELECT category_id,group_id,permission_type FROM category_groups ORDER BY category_id,group_id",
            "groups" => "SELECT id,name,automatic FROM groups ORDER BY id",
            "uploads" => "SELECT id,url,sha1,filesize,secure FROM uploads ORDER BY id",
            "optimized_images" => "SELECT * FROM optimized_images ORDER BY id",
          }
          if @configuration.preuploaded?
            tables[
              "uploads"
            ] = "SELECT id,url,etag,sha1,filesize,secure,original_sha1,original_filename,extension,access_control_post_id FROM uploads ORDER BY id"
            if side == "source"
              result["controlling_posts"] = connection
                .exec(
                  "SELECT DISTINCT p.id,p.topic_id FROM posts p JOIN uploads u ON u.access_control_post_id=p.id",
                )
                .to_h { |r| r.values_at("id", "topic_id") }
            end
          end
          result["media_origins"] = connection
            .exec(
              "SELECT name,value FROM backup_metadata WHERE name IN ('base_url','cdn_url','s3_cdn_url','s3_base_url') ORDER BY name",
            )
            .to_h { |row| row.values_at("name", "value") }
          if side == "destination"
            tables["form_templates"] = "SELECT id,name,template FROM form_templates ORDER BY id"
            result["group_name_max_length"] = (
              connection
                .exec("SELECT value FROM site_settings WHERE name='max_username_length'")
                .first
                &.fetch("value") || 20
            ).to_i
          end
          if side == "source"
            if @configuration.data.key?("preserved_broken_post_uploads")
              result["preserved_broken_post_uploads"] = ReviewedPostUploads.capture(
                connection,
                @configuration.data.fetch("preserved_broken_post_uploads"),
              )
            end
            if @configuration.data.key?("preserved_broken_revision_uploads")
              result["preserved_broken_revision_uploads"] = ReviewedRevisionUploads.capture(
                connection,
                @configuration.data.fetch("preserved_broken_revision_uploads"),
              )
            end
            tables["category_form_templates"] = <<~SQL
              SELECT cf.category_id, cf.form_template_id, ft.name, ft.template
              FROM category_form_templates cf LEFT JOIN form_templates ft ON ft.id=cf.form_template_id
              ORDER BY cf.id
            SQL
            tables["topics"] = <<~SQL
              SELECT id, category_id, archetype, CASE WHEN archetype='regular' THEN title END AS title,
                     deleted_at, visible, closed, archived, created_at, updated_at, bumped_at, last_posted_at,
                     EXISTS(SELECT 1 FROM shared_drafts WHERE topic_id=topics.id) AS shared_draft
              FROM topics ORDER BY id
            SQL
            members = connection.exec(<<~SQL)
              SELECT u.id, u.username, e.email, img.id AS public_avatar_id
              FROM users u JOIN user_emails e ON e.user_id=u.id AND e.primary
              LEFT JOIN uploads img ON img.id=u.uploaded_avatar_id AND NOT img.secure
                AND img.access_control_post_id IS NULL AND img.width>0 AND img.height>0
                AND lower(ltrim(img.extension,'.')) IN ('jpg','jpeg','png','gif','webp','avif','ico','heic','heif','jxl')
              WHERE u.id>0 ORDER BY u.id
            SQL
            members.each do |row|
              id = row.fetch("id").to_i
              member_emails[id] = row.delete("email")
              source_members[id] = row
            end
            result["importable_user_ids"] = member_emails.keys
          end
          tables.each { |name, sql| result[name] = connection.exec(sql).to_a }
          if side == "source"
            result.merge!(plugin_inventory(connection))
            result["pending_entities"] = %w[
              drafts
              draft_sequences
              queued_posts
              reviewables
              reviewable_scores
              reviewable_histories
            ].to_h do |table|
              exists = connection.exec_params("SELECT to_regclass($1)", [table]).getvalue(0, 0)
              [
                table,
                exists ? connection.exec("SELECT count(*) FROM #{table}").getvalue(0, 0).to_i : 0,
              ]
            end
            result["posts_without_topics"] = connection.exec(<<~SQL).getvalue(0, 0).to_i
              SELECT count(*) FROM posts p
              WHERE NOT EXISTS (SELECT 1 FROM topics t WHERE t.id = p.topic_id)
            SQL
            result["solved"] = %w[
              discourse_solved_solved_topics
              discourse_solved_topic_answers
              discourse_solved_shared_issues
            ].to_h do |table|
              exists = connection.exec_params("SELECT to_regclass($1)", [table]).getvalue(0, 0)
              [table, exists ? connection.exec("SELECT * FROM #{table} ORDER BY id").to_a : []]
            end
          end
          result["columns"] = connection.exec(
            "SELECT table_name,column_name,udt_name,is_nullable FROM information_schema.columns WHERE table_schema='public' ORDER BY table_name,ordinal_position",
          ).to_a
          result["counts"] = %w[categories users topics posts uploads].to_h do |table|
            [table, connection.exec("SELECT count(*) FROM #{table}").getvalue(0, 0).to_i]
          end
          if side == "source"
            result["privileged_accounts"] = connection
              .exec(
                "SELECT u.id,u.username,u.admin,u.moderator,e.email FROM users u LEFT JOIN user_emails e ON e.user_id=u.id AND e.primary WHERE u.id>0 AND (u.admin OR u.moderator) ORDER BY u.id",
              )
              .map do |account|
                email = account.delete("email")
                member_emails[account.fetch("id").to_i] = email if email
                account
              end
            result["group_dependencies"] = connection.exec(<<~SQL).to_a
              SELECT 'topic_allowed_groups' AS table_name, a.group_id::bigint, NULL::bigint AS category_id, a.topic_id::bigint, NULL::bigint AS tag_group_id
              FROM topic_allowed_groups a JOIN topics t ON t.id=a.topic_id
              UNION ALL
              SELECT 'tag_group_permissions', group_id, NULL, NULL, tag_group_id FROM tag_group_permissions
              UNION ALL
              SELECT 'category_posting_review_groups', group_id, category_id, NULL, NULL FROM category_posting_review_groups
              UNION ALL
              SELECT 'categories.reviewable_by_group_id', reviewable_by_group_id, id, NULL, NULL FROM categories WHERE reviewable_by_group_id IS NOT NULL
              ORDER BY table_name, group_id, category_id, topic_id, tag_group_id
            SQL
            metadata_tables = {
              "category_custom_fields" =>
                "SELECT cf.name,cf.value,cf.category_id FROM category_custom_fields cf",
              "topic_custom_fields" =>
                "SELECT cf.name,cf.value,cf.topic_id FROM topic_custom_fields cf",
              "post_custom_fields" =>
                "SELECT cf.name,cf.value,p.topic_id FROM post_custom_fields cf JOIN posts p ON p.id=cf.post_id",
              "user_custom_fields" =>
                "SELECT cf.name,cf.value,cf.user_id FROM user_custom_fields cf",
            }
            metadata_tables.each do |table, query|
              connection
                .exec(
                  "#{query} WHERE cf.value LIKE '%group_id%' OR cf.name IN ('group_id','group_ids') ORDER BY cf.id",
                )
                .each do |row|
                  value = row.fetch("value")
                  value = JSON.parse(value) if value&.start_with?("{", "[")
                  ids =
                    GroupMapping.metadata_group_ids(value) |
                      GroupMapping.metadata_group_ids({ row.fetch("name") => value })
                  ids.each do |id|
                    result["group_dependencies"] << row.slice(
                      "category_id",
                      "topic_id",
                      "user_id",
                    ).merge("table_name" => table, "group_id" => id)
                  end
                end
            end
          else
            emails = PG::TextEncoder::Array.new.encode(member_emails.values.uniq)
            members = connection.exec_params(<<~SQL, [emails]).to_a
              SELECT e.email, u.id, u.username, u.uploaded_avatar_id
              FROM user_emails e JOIN users u ON u.id=e.user_id
              WHERE e.email=ANY($1::text[]) ORDER BY e.email
            SQL
            matches = members.to_h { |row| [row.fetch("email"), row.fetch("id").to_i] }
            incoming = inventories.fetch("source")
            incoming["group_user_matches"] = member_emails.filter_map do |id, email|
              if matches.key?(email)
                { "source_user_id" => id, "destination_user_id" => matches.fetch(email) }
              end
            end
            incoming["account_matches"] = incoming.fetch("group_user_matches")
            incoming["matched_avatars"] = MatchedAvatars.decisions(
              incoming.fetch("account_matches"),
              source_members,
              members.index_by { |row| row.fetch("id").to_i },
            )
            incoming["canonical_account_matches"] = incoming
              .fetch("system_accounts")
              .filter_map do |account|
                if result.fetch("system_accounts").include?(account)
                  {
                    "source_user_id" => account.fetch("id").to_i,
                    "destination_user_id" => account.fetch("id").to_i,
                  }
                end
              end
          end
          result["group_memberships"] = connection.exec(<<~SQL).to_a
            SELECT group_id, user_id FROM group_users WHERE user_id > 0 ORDER BY group_id, user_id
          SQL
          result["private_message_grants"] = connection.exec(<<~SQL).to_a
            WITH affected AS (
              SELECT DISTINCT a.topic_id
              FROM topic_allowed_groups a
              JOIN groups g ON g.id = a.group_id AND NOT g.automatic
              JOIN topics t ON t.id = a.topic_id AND t.archetype = 'private_message'
            )
            SELECT a.topic_id, a.group_id, NULL AS user_id
            FROM topic_allowed_groups a JOIN affected USING (topic_id)
            UNION ALL
            SELECT a.topic_id, NULL, a.user_id
            FROM topic_allowed_users a JOIN affected USING (topic_id)
            ORDER BY topic_id, group_id, user_id
          SQL
          result["content"] = ContentInventory.capture(
            connection,
            side,
            result,
            @configuration,
          ) if content
          inventories[side] = result
          @progress&.say(
            result.fetch("counts").map { |table, count| "#{count} #{table}" }.join(", "),
          )
        end
      end
      inventories
    rescue PG::Error => error
      raise Error, "Database inventory failed: #{error.message}"
    end

    private

    def plugin_inventory(connection)
      plugin_tables = connection.exec(<<~SQL).column_values(0)
        SELECT tablename FROM pg_tables WHERE schemaname='public'
          AND (tablename ~ '^(discourse_|chat_|topic_voting_|post_voting_)'
            OR tablename IN ('user_chat_channel_memberships', 'user_chat_thread_memberships'))
        ORDER BY tablename
      SQL
      supported = %w[
        discourse_solved_solved_topics
        discourse_solved_topic_answers
        discourse_solved_shared_issues
      ]
      counts =
        plugin_tables.to_h do |table|
          count =
            connection.exec("SELECT count(*) FROM #{PG::Connection.quote_ident(table)}").getvalue(
              0,
              0,
            )
          [table, count.to_i]
        end
      omitted = inactive_chat_tables(connection, counts)
      if plugin_tables.include?("discourse_reactions_reactions") &&
           counts.fetch("discourse_reactions_reaction_users", 0).zero? &&
           connection.exec(
             "SELECT count(*) FROM discourse_reactions_reactions WHERE coalesce(reaction_users_count,0)>0",
           ).getvalue(0, 0) == "0"
        omitted << "discourse_reactions_reactions"
      end
      if plugin_tables.include?("topic_voting_topic_vote_count") &&
           counts.fetch("topic_voting_votes", 0).zero? &&
           connection.exec(
             "SELECT count(*) FROM topic_voting_topic_vote_count WHERE votes_count<>0",
           ).getvalue(0, 0) == "0"
        omitted << "topic_voting_topic_vote_count"
      end
      {
        "plugin_entities" => counts,
        "omitted_plugin_entities" => counts.slice(*omitted),
        "unsupported_entities" => counts.except(*supported, *omitted),
      }
    end

    def inactive_chat_tables(connection, counts)
      return [] if counts.fetch("chat_messages", 0).nonzero?

      omitted = %w[chat_channels user_chat_channel_memberships]
      # Empty message tables can leave thread records and memberships behind.
      # Titles and custom fields still carry content even without messages.
      if counts["chat_messages"] == 0 && counts.fetch("chat_threads", 0).positive? &&
           counts.fetch("chat_thread_custom_fields", 0).zero? &&
           connection.exec("SELECT EXISTS (SELECT 1 FROM chat_threads WHERE title <> '')").getvalue(
             0,
             0,
           ) == "f"
        omitted += %w[chat_threads user_chat_thread_memberships]
      end
      omitted
    end

    def snapshot(side, source_connection)
      if side == "source" && source_connection
        yield source_connection
      else
        connect(side) do |connection|
          connection.exec("BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY")
          yield connection
        end
      end
    end
  end
end
