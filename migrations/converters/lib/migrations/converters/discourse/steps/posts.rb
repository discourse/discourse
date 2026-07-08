# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class Posts < Conversion::Step
        # One log entry for the whole run: each worker tallies foreign-host links
        # per host, and the reducer (`combine_results`) merges the tallies into a
        # single entry with the full host list in `details`, sorted by link count.
        # Posts link many other Discourse sites, so a long list of hosts with a few
        # links each is normal and the entry stays INFO. It becomes a WARNING (and
        # the step shows one warning) only when a single host holds a large share
        # of the links — the typical sign of a former domain that is missing from
        # the `source_site` settings.
        FOREIGN_LINK_LOG_MESSAGE = "Internal-looking links on unconfigured hosts"

        # A host counts as dominant when it holds this share of all foreign
        # route-shaped links AND at least this many links, so a small forum with a
        # handful of links never triggers the warning. On a large forum without
        # former domains, the most-linked foreign host stayed around 15%.
        DOMINANT_HOST_SHARE = 0.25
        DOMINANT_HOST_MINIMUM = 100
        private_constant :DOMINANT_HOST_SHARE, :DOMINANT_HOST_MINIMUM

        # Merges every worker's per-host link tally and writes the one log entry.
        # Runs in the parent under the run DB's single-writer discipline (see
        # {StepCoordinator#reduce_results}); `results` are the workers' `result`
        # hashes, with string keys from crossing the process boundary as JSON.
        # Returns 1 (one warning) when a host dominates, else 0.
        def self.combine_results(results)
          totals = Hash.new(0)
          results.each { |hosts| hosts.each { |host, count| totals[host] += count } }
          return 0 if totals.empty?

          total = totals.values.sum
          hosts = totals.sort_by { |host, count| [-count, host] }
          top_count = hosts.first[1]
          dominant = top_count >= DOMINANT_HOST_MINIMUM && top_count >= total * DOMINANT_HOST_SHARE

          IntermediateDB::LogEntry.create(
            type: dominant ? IntermediateDB::LogEntry::WARNING : IntermediateDB::LogEntry::INFO,
            message: FOREIGN_LINK_LOG_MESSAGE,
            details: {
              total:,
              hosts: hosts.map { |host, count| { host:, count: } },
            },
          )

          dominant ? 1 : 0
        end

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
          attr_accessor :group_names,
                        :here_mention,
                        :mention_names,
                        :hashtag_names,
                        :custom_emoji_names,
                        :internal_link_hosts

          def setup
            # Tally foreign-host links per host, with no logging or tracker calls —
            # this runs while posts are scanned, and a real forum has tens of
            # thousands of these links. `result` sends the tally to the parent,
            # where `combine_results` merges all workers' tallies into one log
            # entry.
            @foreign_hosts = Hash.new(0)

            @extractor =
              RawExtractor.new(
                mention_resolver:
                  MentionResolver.new(here_mention:, group_names: group_names || []),
                mention_names:,
                hashtag_names:,
                custom_emoji_names:,
                internal_link_hosts: internal_link_hosts || Set.new,
                on_foreign_host: ->(host) { @foreign_hosts[host] += 1 },
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

          # The worker's per-host link tally, sent to `combine_results` in the
          # parent. Nil when this worker saw no foreign-host links, so it sends
          # nothing.
          def result
            @foreign_hosts unless @foreign_hosts.empty?
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
