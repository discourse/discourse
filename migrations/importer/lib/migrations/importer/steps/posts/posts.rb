# frozen_string_literal: true

module Migrations
  module Importer
    module Steps
      class Posts < CopyStep
        POST_TYPES = Post.types.values.to_set.freeze
        DEFAULT_POST_TYPE = Post.types[:regular]
        HIDDEN_REASONS = Post.hidden_reasons.values.to_set.freeze
        SUPPORTED_LOCALES = LocaleSiteSetting.supported_locales.to_set.freeze
        WORD_PATTERN = /[[:word:]]+/
        NULL_BYTE = "\u0000"

        depends_on :topics, :users, :uploads, :categories, :tags, :groups, :badges
        store_mapped_ids true

        # The placeholders of a whole copy batch are resolved with one call, so
        # its linkage rows are read with one query per embed kind.
        batch_size DiscourseDB::COPY_BATCH_SIZE

        column_names %i[
                       id
                       action_code
                       cooked
                       created_at
                       deleted_at
                       deleted_by_id
                       hidden
                       hidden_at
                       hidden_reason_id
                       last_editor_id
                       last_version_at
                       like_count
                       locale
                       locked_by_id
                       post_number
                       post_type
                       raw
                       reply_to_post_number
                       reply_to_user_id
                       sort_order
                       topic_id
                       updated_at
                       user_deleted
                       user_id
                       wiki
                       word_count
                     ]

        total_rows_query <<~SQL, MappingType::POSTS
          SELECT COUNT(*)
          FROM posts
               LEFT JOIN mapped.ids mapped_post
                 ON posts.original_id = mapped_post.original_id AND mapped_post.type = ?1
          WHERE mapped_post.original_id IS NULL
        SQL

        rows_query <<~SQL, MappingType::POSTS, MappingType::TOPICS, MappingType::USERS
          SELECT posts.*,
                 post_numbers.post_number              AS discourse_post_number,
                 reply_numbers.post_number             AS discourse_reply_to_post_number,
                 mapped_topic.discourse_id             AS discourse_topic_id,
                 mapped_user.discourse_id              AS discourse_user_id,
                 mapped_editor.discourse_id            AS discourse_last_editor_id,
                 mapped_reply_user.discourse_id        AS discourse_reply_to_user_id,
                 mapped_deleted_by_user.discourse_id   AS discourse_deleted_by_id,
                 mapped_locked_by_user.discourse_id    AS discourse_locked_by_id
          FROM posts
               JOIN mapped.post_numbers post_numbers
                 ON posts.original_id = post_numbers.original_id
               LEFT JOIN mapped.post_numbers reply_numbers
                 ON posts.reply_to_post_id = reply_numbers.original_id
                    AND posts.topic_id = reply_numbers.topic_original_id
               LEFT JOIN mapped.ids mapped_post
                 ON posts.original_id = mapped_post.original_id AND mapped_post.type = ?1
               LEFT JOIN mapped.ids mapped_topic
                 ON posts.topic_id = mapped_topic.original_id AND mapped_topic.type = ?2
               LEFT JOIN mapped.ids mapped_user
                 ON posts.user_id = mapped_user.original_id AND mapped_user.type = ?3
               LEFT JOIN mapped.ids mapped_editor
                 ON posts.last_editor_id = mapped_editor.original_id AND mapped_editor.type = ?3
               LEFT JOIN mapped.ids mapped_reply_user
                 ON posts.reply_to_user_id = mapped_reply_user.original_id
                    AND mapped_reply_user.type = ?3
               LEFT JOIN mapped.ids mapped_deleted_by_user
                 ON posts.deleted_by_id = mapped_deleted_by_user.original_id
                    AND mapped_deleted_by_user.type = ?3
               LEFT JOIN mapped.ids mapped_locked_by_user
                 ON posts.locked_by_id = mapped_locked_by_user.original_id
                    AND mapped_locked_by_user.type = ?3
          WHERE mapped_post.original_id IS NULL
          ORDER BY posts.original_id
        SQL

        private

        def setup
          @resolved_raw = {}
        end

        def before(total_rows:)
          # Everything the run adds gets an id above this one, which is how the
          # `after` hook finds the topics it has to update.
          @first_new_post_id = @discourse_db.last_id_of("posts") + 1

          PostNumbering.new(@intermediate_db).assign

          @maps = PlaceholderMaps.new(@intermediate_db, @discourse_db)
          @unresolved_embeds = UnresolvedEmbedReport.new(@intermediate_db)
          @resolver =
            PlaceholderResolver.new(
              @intermediate_db,
              @maps,
              owner_type: Enums::EmbedOwner::POST,
              trusted_upload_hosts: @config[:trusted_upload_hosts] || [],
              unresolved_embeds: @unresolved_embeds,
            )
        end

        def before_batch(rows)
          original_ids = rows.map { |row| row[:original_id] }
          @maps.prime_posts(original_ids)

          items = rows.map { |row| { id: row[:original_id], raw: row[:raw] } }
          @resolved_raw = @resolver.resolve_all(items)

          report_orphan_placeholders
        end

        def transform_row(row)
          if row[:discourse_topic_id].nil?
            notice(
              I18n.t(
                "importer.posts.topic_not_imported",
                post_id: row[:original_id],
                topic_id: row[:topic_id],
              ),
            )
            return nil
          end

          row[:topic_id] = row[:discourse_topic_id]
          row[:post_number] = row[:discourse_post_number]
          row[:sort_order] = row[:post_number]
          # A reply to the first post is a reply to the topic; core stores no
          # number for that.
          row[:reply_to_post_number] = row[:discourse_reply_to_post_number]
          row[:reply_to_post_number] = nil if row[:reply_to_post_number] == 1

          row[:user_id] = row[:discourse_user_id] || SYSTEM_USER_ID
          row[:last_editor_id] = row[:discourse_last_editor_id] || row[:user_id]
          row[:reply_to_user_id] = row[:discourse_reply_to_user_id]
          row[:deleted_by_id] = row[:discourse_deleted_by_id]
          row[:locked_by_id] = row[:discourse_locked_by_id]

          row[:raw] = clean_raw(@resolved_raw[row[:original_id]] || row[:raw])
          row[:word_count] = row[:raw].scan(WORD_PATTERN).size

          # A rebake after the import fills this in. Cooking here would need the
          # markdown pipeline for every post and still be wrong for the posts
          # whose quotes point at posts of a later batch.
          row[:cooked] = ""

          row[:hidden] ||= false
          row[:user_deleted] ||= false
          row[:wiki] ||= false
          row[:like_count] ||= 0

          row[:post_type] ||= DEFAULT_POST_TYPE
          row[:post_type] = ensure_valid_value(
            value: row[:post_type],
            allowed_set: POST_TYPES,
            default_value: DEFAULT_POST_TYPE,
          ) do |value, default_value|
            notice(
              I18n.t(
                "importer.posts.invalid_post_type",
                post_id: row[:original_id],
                post_type: value,
                default_post_type: default_value,
              ),
            )
          end

          if row[:hidden_reason_id]
            row[:hidden_reason_id] = ensure_valid_value(
              value: row[:hidden_reason_id],
              allowed_set: HIDDEN_REASONS,
              default_value: nil,
            )
          end

          if row[:locale] && SUPPORTED_LOCALES.exclude?(row[:locale])
            notice(
              I18n.t(
                "importer.posts.invalid_locale",
                post_id: row[:original_id],
                value: row[:locale],
              ),
            )
            row[:locale] = nil
          end

          row[:created_at] ||= NOW
          row[:last_version_at] = row[:created_at]

          super
        end

        # An orphan means a token lost its linkage row on the way, which leaves
        # a hole in the body. That is a bug, not bad source data.
        def report_orphan_placeholders
          orphans = @resolver.orphan_placeholders
          return if orphans.empty?

          orphans.each do |orphan|
            notice(
              I18n.t(
                "importer.posts.orphan_placeholder",
                post_id: orphan.owner_id,
                kind: orphan.kind,
              ),
            )
          end
          orphans.clear
        end

        def clean_raw(raw)
          raw = raw.to_s.scrub
          # PostgreSQL rejects a NUL byte in a text column, and the rest of the
          # body is worth more than that byte.
          raw = raw.delete(NULL_BYTE) if raw.include?(NULL_BYTE)
          # No strip: leading whitespace can be an indented code block.
          raw.presence || I18n.t("importer.posts.empty_raw")
        end

        def after(total_rows:)
          return if total_rows == 0

          update_topic_statistics
          report_unresolved_embeds
        end

        # Only the topic columns a new post changes. User stats, post timings
        # and post replies need the whole destination, so they stay with
        # `rake import:ensure_consistency`.
        def update_topic_statistics
          DB.exec(<<~SQL, first_post_id: @first_new_post_id)
            WITH touched AS (
              SELECT DISTINCT topic_id
              FROM posts
              WHERE id >= :first_post_id
            ),
            public_posts AS (
              SELECT posts.topic_id,
                     MAX(posts.post_number) AS highest_post_number,
                     COUNT(*) AS posts_count,
                     MAX(posts.created_at) AS last_posted_at
              FROM posts
                   JOIN touched ON touched.topic_id = posts.topic_id
              WHERE posts.deleted_at IS NULL AND #{Topic.public_post_types_sql}
              GROUP BY posts.topic_id
            ),
            staff_posts AS (
              SELECT posts.topic_id,
                     MAX(posts.post_number) AS highest_staff_post_number
              FROM posts
                   JOIN touched ON touched.topic_id = posts.topic_id
              WHERE posts.deleted_at IS NULL AND #{Topic.staff_post_types_sql}
              GROUP BY posts.topic_id
            ),
            last_posters AS (
              SELECT DISTINCT ON (posts.topic_id) posts.topic_id, posts.user_id
              FROM posts
                   JOIN touched ON touched.topic_id = posts.topic_id
              WHERE posts.deleted_at IS NULL
                AND NOT posts.hidden
                AND #{Topic.public_post_types_sql}
              ORDER BY posts.topic_id, posts.post_number DESC
            )
            UPDATE topics
            SET highest_post_number = public_posts.highest_post_number,
                highest_staff_post_number =
                  COALESCE(staff_posts.highest_staff_post_number, public_posts.highest_post_number),
                posts_count = public_posts.posts_count,
                last_posted_at = public_posts.last_posted_at,
                bumped_at = COALESCE(public_posts.last_posted_at, topics.bumped_at),
                last_post_user_id = COALESCE(last_posters.user_id, topics.last_post_user_id)
            FROM public_posts
                 LEFT JOIN staff_posts ON staff_posts.topic_id = public_posts.topic_id
                 LEFT JOIN last_posters ON last_posters.topic_id = public_posts.topic_id
            WHERE topics.id = public_posts.topic_id
          SQL
        end

        def report_unresolved_embeds
          @unresolved_embeds
            .counts_by_kind
            .sort_by { |kind, _| kind.to_s }
            .each do |kind, count|
              notice(I18n.t("importer.posts.unresolved_embeds", kind:, count:))
            end
        end
      end
    end
  end
end
