# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class Posts < Conversion::Step
        # One log entry for the whole run, listing the hosts that carried
        # internal-looking links without being configured as the source's own —
        # where to look when a former domain is missing from the `source_site`
        # settings. The extractor reports a host once, not once per link, so this
        # is a set of host names and not a ranking; posts link many other
        # Discourse sites, so a long list is normal and the entry stays INFO.
        FOREIGN_LINK_LOG_MESSAGE = "Internal-looking links on unconfigured hosts"

        # An engine refusal is a body whose extraction was abandoned rather than
        # guessed at, so each one is named: these are the posts an operator has to
        # look at before trusting the converted body.
        ENGINE_REFUSAL_LOG_MESSAGE = "Post embeds not extracted"

        # A heads-up, not a problem: the body extracted fine, it just needed the
        # slow retry to parse.
        SLOW_PARSE_LOG_MESSAGE = "Post body needed the slow markdown parse"

        # The most hosts we keep in `details`. The former-domain forensics only
        # need a sample, and an unbounded list bloats one log row on link-heavy
        # forums.
        DETAILS_HOST_LIMIT = 500
        private_constant :DETAILS_HOST_LIMIT

        # How many posts a worker reads and prepares before one round of engine
        # scans. The extractor splits a round into V8 calls of its own, so this
        # size only decides how many bodies a worker holds at once: enough that
        # the per-round bookkeeping disappears next to the scanning, few enough
        # that the held bodies stay a rounding error against the worker's memory.
        BATCH_SIZE = 256

        # Merges the workers' host lists into the run's one entry, logged through
        # `tracker` so the step's tallies pick it up (see
        # {StepCoordinator#reduce_results}). Runs in the parent under the run DB's
        # single-writer discipline; `results` are the workers' `result` arrays,
        # which crossed the process boundary as JSON.
        def self.combine_results(results, tracker)
          hosts = results.flatten.uniq.sort
          return if hosts.empty?

          kept = hosts.take(DETAILS_HOST_LIMIT)
          details = { total: hosts.size, hosts: kept }
          omitted = hosts.size - kept.size
          details[:omitted] = omitted if omitted > 0

          tracker.log_info(FOREIGN_LINK_LOG_MESSAGE, details:)
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
          batch_size BATCH_SIZE

          attr_accessor :group_names,
                        :here_mention,
                        :mention_names,
                        :hashtag_names,
                        :custom_emoji_names,
                        :markdown_bundle,
                        :markdown_config,
                        :internal_link_hosts,
                        :internal_link_base_prefix

          def setup
            # Collect the foreign hosts with no logging or tracker calls — this
            # runs while posts are scanned. `result` sends the list to the parent,
            # where `combine_results` merges every worker's into one log entry.
            @foreign_hosts = Set.new

            # One buffer, reused (cleared) per post — a fresh one would allocate a
            # new placeholder (a random nonce) for every post, most of which record
            # nothing. The extractor binds it once at construction and records onto
            # it on every extraction.
            @embeds = EmbedBuffer.new(owner_type: Enums::EmbedOwner::POST)

            # A V8 isolate does not survive a fork, so the engine is built here, in
            # the worker, out of the bundle the parent loaded once. There is no
            # processor cleanup hook to close it in; the worker exits when the step
            # is done and takes the isolate with it.
            @markdown_engine =
              MarkdownEngine::Context.new(bundle: markdown_bundle, config: markdown_config)

            @extractor =
              RawExtractor.new(
                embeds: @embeds,
                mention_classifier:
                  MentionClassifier.new(here_mention:, group_names: group_names || []),
                mention_names:,
                hashtag_names:,
                markdown_engine: @markdown_engine,
                custom_emoji_names:,
                internal_link_hosts: internal_link_hosts || {},
                internal_link_base_prefix:,
                on_foreign_host: ->(host) { @foreign_hosts << host },
                on_engine_refusal: ->(cause, detail) { log_refusal(cause, detail) },
                on_slow_parse: -> { log_slow_parse },
              )
          end

          def process_batch(items)
            prepared = prepare_bodies(items)
            scan_data = @extractor.scan_batches(prepared.values.select(&:engine_bound?))

            items.each do |item|
              convert(item, prepared[item[:id]], scan_data)
            rescue StandardError => e
              # A body the extraction chokes on costs its own post, not the rest of
              # the batch it happens to share.
              tracker.log_error("Failed to process post", exception: e, details: { id: item[:id] })
            end
          end

          # The foreign hosts this worker saw, sent to `combine_results` in the
          # parent. Nil when it saw none, so it sends nothing.
          def result
            @foreign_hosts.sort unless @foreign_hosts.empty?
          end

          private

          # Normalizes and classifies every body up front, so one round of engine
          # scans covers the whole batch. A post with no body has nothing to scan
          # and stays out of the round; it still gets its row.
          def prepare_bodies(items)
            prepared = {}

            items.each do |item|
              raw = item[:raw]
              next if raw.nil? || raw.empty?

              prepared[item[:id]] = @extractor.prepare(
                raw:,
                id: item[:id],
                topic_id: item[:topic_id],
              )
            end

            prepared
          end

          def convert(item, prepared, scan_data)
            @embeds.clear
            raw = prepared ? extract(prepared, scan_data[item[:id]]) : item[:raw]

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
              locale: item[:locale],
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

          # The extractor reports a refusal or a slow parse while it scans and has
          # no idea which post it is working on, so the id waits here for the
          # callbacks.
          def extract(prepared, scan_data)
            @post_id = prepared.id
            @extractor.extract_prepared(prepared, scan_data:)
          end

          def log_refusal(cause, detail)
            tracker.log_warning(
              ENGINE_REFUSAL_LOG_MESSAGE,
              details: { id: @post_id, cause:, detail: }.compact,
            )
          end

          def log_slow_parse
            tracker.log_info(SLOW_PARSE_LOG_MESSAGE, details: { id: @post_id })
          end

          # Keeps only values the enum recognizes, otherwise the fallback (the
          # source may carry values from plugins or versions we don't model).
          def valid_enum(enum_module, value, fallback: nil)
            enum_module.valid?(value) ? value : fallback
          end
        end
      end
    end
  end
end
