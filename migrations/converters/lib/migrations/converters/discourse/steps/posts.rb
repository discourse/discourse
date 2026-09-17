# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class Posts < Conversion::Step
        # Limits the hosts in `details`. The list only has to show where a
        # former domain is missing; more would bloat the log entry.
        DETAILS_HOST_LIMIT = 500

        # Posts a worker reads and prepares before one round of engine scans.
        # The extractor splits the round into V8 calls itself, so this only
        # limits how many bodies a worker holds in memory at once.
        BATCH_SIZE = 256

        SOURCE_COLUMNS = %i[
          id
          action_code
          created_at
          deleted_at
          deleted_by_id
          hidden
          hidden_at
          hidden_reason_id
          last_editor_id
          like_count
          locale
          locked_by_id
          raw
          post_number
          post_type
          reply_to_user_id
          sort_order
          topic_id
          user_deleted
          user_id
          wiki
        ].freeze
        private_constant :DETAILS_HOST_LIMIT, :BATCH_SIZE, :SOURCE_COLUMNS

        # Merges the workers' host lists into one log entry. Runs in the parent;
        # `results` are the workers' `result` values after their trip through JSON.
        def self.combine_results(results, tracker)
          hosts = results.flatten.uniq.sort
          return if hosts.empty?

          kept = hosts.take(DETAILS_HOST_LIMIT)
          details = { total: hosts.size, hosts: kept }
          omitted = hosts.size - kept.size
          details[:omitted] = omitted if omitted > 0

          # Logged at INFO: posts link to many other Discourse sites, so a long
          # list is normal. The extractor reports each host once, so this is a
          # list of hosts, not a count of links. Look here when a former domain
          # is missing from the `source_site` settings.
          tracker.log_info(I18n.t("converters.discourse.posts.foreign_hosts"), details:)
        end

        source do
          # Posts is the heaviest step, so it runs on several forks. Partition on
          # `(topic_id, post_number)` instead of `id`: that pair is the target
          # table's index, so each fork's shard merges into the run DB as
          # sequential index appends. Partitioning on `id` made the merge about
          # twice as slow.
          partition_by %i[topic_id post_number], from: "posts"

          def max_progress
            @source_db.count(<<~SQL)
              SELECT COUNT(*) FROM posts #{partition_where}
            SQL
          end

          def items
            # `reply_to_post_id` is the parent post's id, found by
            # `reply_to_post_number` within the same topic, so the reference
            # survives renumbering at import. The self-join reads every post, so
            # a parent in another chunk still resolves.
            selected_columns = SOURCE_COLUMNS.map { |column| "posts.#{column}" }.join(", ")

            @source_db.query(<<~SQL)
              SELECT #{selected_columns},
                     reply_to.id AS reply_to_post_id
                FROM posts
                     LEFT JOIN posts AS reply_to
                       ON reply_to.topic_id = posts.topic_id
                      AND reply_to.post_number = posts.reply_to_post_number
              #{partition_where(key: %i[posts.topic_id posts.post_number])}
              ORDER BY posts.topic_id, posts.post_number
            SQL
          end

          private

          # Empty when the step runs unpartitioned (inline or on a single fork).
          def partition_where(key: nil)
            slice = partition_slice(key:)
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
            # Only collected here. `result` sends the list to the parent, which
            # merges all workers' lists in `combine_results`.
            @foreign_hosts = Set.new

            # One buffer for all posts. A new one per post would create a new
            # placeholder nonce each time.
            @embeds = EmbedBuffer.new(owner_type: Enums::EmbedOwner::POST)

            # A V8 isolate doesn't survive a fork, so the context is built in the
            # worker from the bundle the parent loaded.
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
                internal_link_hosts:,
                internal_link_base_prefix:,
                on_foreign_host: ->(host) { @foreign_hosts << host },
                on_engine_refusal: ->(cause, detail) { log_refusal(cause, detail) },
                on_slow_parse: -> { log_slow_parse },
              )
          end

          def cleanup
            @markdown_engine&.close
          end

          def process_batch(items)
            prepared = prepare_bodies(items)
            scan_data = @extractor.scan_batches(prepared.values.select(&:engine_bound?))

            items.each do |item|
              convert(item, prepared[item[:id]], scan_data)
            rescue StandardError => e
              # One bad body shouldn't fail the whole batch.
              tracker.log_error(
                I18n.t("converters.discourse.posts.post_failed"),
                exception: e,
                details: {
                  id: item[:id],
                },
              )
            end
          end

          # Nil when this worker saw no foreign host, so nothing is sent.
          def result
            @foreign_hosts.sort unless @foreign_hosts.empty?
          end

          private

          # A post without a body gets a row but no scan.
          def prepare_bodies(items)
            prepared = {}

            items.each do |item|
              raw = item[:raw]
              next if raw.blank?

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

            # The embed tables are written by `EmbedBuffer#write_for`, which is why
            # the coverage check leaves them out of the per-converter check.
            @embeds.write_for(item[:id])
          end

          # The extractor's callbacks don't know which post is being extracted,
          # so the id is kept here.
          def extract(prepared, scan_data)
            @post_id = prepared.id
            @extractor.extract_prepared(prepared, scan_data:)
          end

          # The extractor refused the body instead of guessing. Someone has to look
          # at these posts before the converted body can be trusted.
          def log_refusal(cause, detail)
            tracker.log_warning(
              I18n.t("converters.discourse.posts.embeds_not_extracted"),
              details: { id: @post_id, cause:, detail: }.compact,
            )
          end

          # Not a problem, the body was extracted. It only needed the slow retry.
          def log_slow_parse
            tracker.log_info(
              I18n.t("converters.discourse.posts.slow_parse"),
              details: {
                id: @post_id,
              },
            )
          end

          # The source may carry values from plugins or versions we don't model.
          def valid_enum(enum_module, value, fallback: nil)
            enum_module.valid?(value) ? value : fallback
          end
        end
      end
    end
  end
end
