# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class Posts < Conversion::Step
        source do
          # Posts is the heaviest step, so split it across forks. Partition on the
          # composite `(topic_id, post_number)`, not the obvious `id`: that pair is
          # the target table's index (`idx_posts_topic_id_post_number`), so each fork
          # converts a contiguous slice of it and the shards merge into the run DB as
          # sequential index appends. Splitting on `id` would spread every fork's rows
          # across that index, turning the merge into random inserts (~2x slower over
          # the run). The pair is effectively unique, so the forks still get even row
          # counts, and a huge topic is split across them instead of landing on one.
          partition_by %i[topic_id post_number], from: "posts"

          def max_progress
            @source_db.count(<<~SQL)
              SELECT COUNT(*) FROM posts #{partition_where}
            SQL
          end

          def items
            # `reply_to_post_id` resolves the source `reply_to_post_number` to the
            # parent post's id (same topic) so the reference survives renumbering.
            # The chunk filter goes on the scan subquery, where `topic_id` is
            # unambiguous next to the `reply_to` self-join (which reads every post,
            # so a parent in another chunk still resolves).
            @source_db.query(<<~SQL)
              SELECT posts.*,
                     reply_to.id AS reply_to_post_id
                FROM (SELECT * FROM posts #{partition_where}) posts
                     LEFT JOIN posts reply_to
                       ON reply_to.topic_id = posts.topic_id
                      AND reply_to.post_number = posts.reply_to_post_number
              ORDER BY posts.topic_id, posts.post_number
            SQL
          end

          private

          # The `WHERE` limiting the scan to this worker's chunk, or "" when the step
          # runs whole (inline or a single fork), where `partition_slice` is nil.
          def partition_where
            slice = partition_slice
            slice ? "WHERE #{slice}" : ""
          end
        end

        processor do
          attr_accessor :group_names, :here_mention, :hashtag_names, :custom_emoji_names

          def setup
            @extractor =
              RawExtractor.new(
                mention_resolver:
                  MentionResolver.new(here_mention:, group_names: group_names || []),
                hashtag_names:,
                custom_emoji_names:,
              )
            # One buffer, reused (cleared) per post — a fresh one would allocate a
            # new placeholder (a random nonce) for every post, most of which record
            # nothing.
            @embeds = EmbedBuffer.new(owner_type: Enums::EmbedOwner::POST)
          end

          def process(item)
            @embeds.clear
            raw = @extractor.extract(item[:raw], on_embed: @embeds, topic_id: item[:topic_id])

            IntermediateDB::Post.create(
              original_id: item[:id],
              action_code: item[:action_code],
              created_at: item[:created_at],
              deleted_at: item[:deleted_at],
              deleted_by_id: item[:deleted_by_id],
              hidden: item[:hidden],
              hidden_at: item[:hidden_at],
              hidden_reason_id: valid_enum(Enums::PostHiddenReason, item[:hidden_reason_id]),
              last_editor_id: item[:last_editor_id],
              like_count: item[:like_count],
              locked_by_id: item[:locked_by_id],
              original_raw: item[:raw],
              post_number: item[:post_number],
              post_type:
                valid_enum(Enums::PostType, item[:post_type], fallback: Enums::PostType::REGULAR),
              raw:,
              reply_to_post_id: item[:reply_to_post_id],
              reply_to_user_id: item[:reply_to_user_id],
              sort_order: item[:sort_order],
              topic_id: item[:topic_id],
              user_deleted: item[:user_deleted],
              user_id: item[:user_id],
              wiki: item[:wiki],
            )

            # The linkage tables are written by the shared `EmbedBuffer#write_for`,
            # not here, so the per-converter coverage check holds them out (see
            # `ReferenceCheck::EMBED_BUFFER_TABLES`).
            @embeds.write_for(item[:id])
          end

          private

          # Keeps only values the enum recognizes, otherwise the fallback (the
          # source may carry values from plugins or versions we don't model).
          def valid_enum(enum_module, value, fallback: nil)
            return fallback if value.nil?
            enum_module.valid?(value) ? value : fallback
          end
        end
      end
    end
  end
end
