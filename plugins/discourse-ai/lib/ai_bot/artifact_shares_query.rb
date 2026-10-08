# frozen_string_literal: true

module DiscourseAi
  module AiBot
    class ArtifactSharesQuery
      FEED_PAGE_SIZE = 20
      MAX_CONVERSATION_SCAN = 100
      FEED_TYPES = %w[all standalone conversation].freeze
      FEED_ORDERS = %w[newest oldest].freeze

      def initialize(user:, type:, order:, cursor:)
        @user = user
        @type = type.nil? ? "all" : type
        @order = order.nil? ? "newest" : order
        @raw_cursor = cursor
      end

      def call
        raise Discourse::InvalidParameters.new(:type) if !FEED_TYPES.include?(@type)
        raise Discourse::InvalidParameters.new(:order) if !FEED_ORDERS.include?(@order)

        filter = @type
        order = @order
        cursor = parse_feed_cursor(@raw_cursor, filter, order) if !@raw_cursor.nil?

        streams = {}
        if filter != "conversation"
          streams["standalone"] = {
            scope: AiArtifactShare.where(user: @user),
            rows: [],
            cards: {
            },
            after: cursor,
          }
        end
        if filter != "standalone"
          streams["conversation"] = {
            scope: SharedAiConversation.where(user: @user, target_type: "Topic"),
            rows: [],
            cards: {
            },
            after: cursor,
          }
        end

        items = []
        conversation_scans = 0
        last_event = nil
        loop do
          streams.each do |type, stream|
            if stream[:rows].empty? && !stream[:exhausted]
              batch_size = FEED_PAGE_SIZE
              if type == "conversation"
                batch_size = [batch_size, MAX_CONVERSATION_SCAN - conversation_scans].min
              end
              load_feed_batch(stream, type, order, batch_size)
            end
          end
          available =
            streams.filter_map { |type, stream| [type, stream[:rows].first] if stream[:rows].any? }
          break if available.empty?

          type, event =
            if order == "newest"
              available.max_by { |event_type, record| [record.created_at, record.id, event_type] }
            else
              available.min_by { |event_type, record| [record.created_at, record.id, event_type] }
            end
          break if type == "conversation" && conversation_scans == MAX_CONVERSATION_SCAN

          stream = streams[type]
          stream[:rows].shift
          items.concat(stream[:cards].fetch(event.id))
          conversation_scans += 1 if type == "conversation"
          last_event = feed_position(event, type)
          break if items.length >= FEED_PAGE_SIZE || conversation_scans == MAX_CONVERSATION_SCAN
        end

        has_more =
          last_event &&
            streams.any? do |type, stream|
              feed_after(stream[:scope], last_event, type, order).exists?
            end
        {
          items: items,
          has_more: !!has_more,
          next_cursor: has_more ? last_event.merge(order: order, filter: filter) : nil,
        }
      end

      private

      def parse_feed_cursor(raw, filter, order)
        raise Discourse::InvalidParameters.new(:cursor) if !raw.is_a?(String) || raw.bytesize > 512

        value = JSON.parse(raw)
        if !value.is_a?(Hash) || value.keys.sort != %w[created_at filter id order type] ||
             value["filter"] != filter || value["order"] != order ||
             !%w[standalone conversation].include?(value["type"]) ||
             (filter != "all" && value["type"] != filter) || !value["id"].is_a?(Integer) ||
             !value["id"].between?(1, 2**63 - 1) || !value["created_at"].is_a?(String) ||
             !value["created_at"].match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{6}Z\z/)
          raise Discourse::InvalidParameters.new(:cursor)
        end

        { created_at: Time.iso8601(value["created_at"]), id: value["id"], type: value["type"] }
      rescue JSON::ParserError, ArgumentError
        raise Discourse::InvalidParameters.new(:cursor)
      end

      def feed_position(record, type)
        { created_at: record.created_at.utc.iso8601(6), id: record.id, type: type }
      end

      def feed_after(scope, cursor, type, order)
        return scope if !cursor

        operator = order == "newest" ? "<" : ">"
        inclusive =
          if (type <=> cursor[:type]) == (order == "newest" ? -1 : 1)
            "="
          else
            ""
          end
        scope.where(
          "created_at #{operator} :time OR (created_at = :time AND id #{operator}#{inclusive} :id)",
          time: cursor[:created_at],
          id: cursor[:id],
        )
      end

      def load_feed_batch(stream, type, order, batch_size)
        direction = order == "newest" ? :desc : :asc
        scope = feed_after(stream[:scope], stream[:after], type, order)
        if type == "standalone"
          batch =
            scope
              .includes(:ai_artifact)
              .order(created_at: direction, id: direction)
              .limit(batch_size)
              .to_a
          viewable_posts = viewable_post_ids(batch)
          policy_allows_viewing = AiArtifactShare.publicly_viewable_by?(@user)
          stream[:cards] = batch.to_h do |share|
            [
              share.id,
              [
                {
                  id: "standalone-#{share.id}",
                  type: "standalone",
                  name: share.name,
                  share_key: share.share_key,
                  url: share.url,
                  version: share.version_number,
                  created_at: share.created_at,
                  available:
                    SiteSetting.ai_artifact_security.in?(%w[lax hybrid strict]) &&
                      policy_allows_viewing && viewable_posts.include?(share.ai_artifact&.post_id),
                },
              ],
            ]
          end
        else
          batch =
            scope.includes(:user).order(created_at: direction, id: direction).limit(batch_size).to_a
          stream[:cards] = conversation_feed_cards(batch)
        end
        stream[:rows] = batch
        stream[:after] = feed_position(batch.last, type) if batch.any?
        stream[:exhausted] = batch.length < batch_size
      end

      def conversation_feed_cards(batch)
        candidates =
          batch.select do |conversation|
            conversation.context.any? do |context_post|
              context_post["cooked"].to_s.match?(/data-(?:ai-)?artifact-id/i)
            end
          end
        topics_by_id =
          Topic.includes(:category).where(id: candidates.map(&:target_id).uniq).index_by(&:id)
        context_post_ids =
          candidates
            .flat_map do |conversation|
              conversation.context.filter_map { |context_post| context_post["id"] }
            end
            .uniq
        posts_by_id =
          Post
            .includes(topic: :category)
            .where(id: context_post_ids, topic_id: topics_by_id.keys)
            .index_by(&:id)
        visible =
          candidates.select do |conversation|
            topic = topics_by_id[conversation.target_id]
            topic && conversation.publicly_visible?(topic: topic, posts_by_id: posts_by_id)
          end
        artifact_versions_by_conversation =
          visible.to_h do |conversation|
            cooked =
              conversation.context.map { |context_post| context_post["cooked"].to_s }.join("\n")
            versions =
              Nokogiri::HTML5
                .fragment(cooked)
                .css("[data-artifact-id], [data-ai-artifact-id]")
                .filter_map do |node|
                  id = (node["data-artifact-id"] || node["data-ai-artifact-id"]).to_i
                  next if id <= 0

                  version = node["data-artifact-version"] || node["data-ai-artifact-version"]
                  version_number = version&.to_i
                  [id, version_number&.positive? ? version_number : nil]
                end
                .to_h
            [conversation.id, versions]
          end
        artifact_ids = artifact_versions_by_conversation.values.flat_map(&:keys).uniq
        artifacts_by_id =
          if artifact_ids.empty?
            {}
          else
            AiArtifact
              .joins(:post)
              .where(id: artifact_ids)
              .pluck(
                "ai_artifacts.id",
                "ai_artifacts.name",
                "posts.topic_id",
                "posts.id",
                "ai_artifacts.metadata",
              )
              .index_by(&:first)
          end

        batch.to_h do |conversation|
          cards =
            artifact_versions_by_conversation
              .fetch(conversation.id, {})
              .filter_map do |artifact_id, version|
                artifact = artifacts_by_id[artifact_id]
                next if !artifact || artifact[2] != conversation.target_id

                {
                  id: "conversation-#{conversation.id}-#{artifact_id}",
                  type: "conversation",
                  name: artifact[1],
                  url: conversation.url,
                  embed_url: AiArtifact.embed_url(artifact_id, version),
                  available:
                    SiteSetting.ai_artifact_security.in?(%w[lax hybrid strict]) &&
                      SiteSetting.discourse_ai_enabled && artifact[4]&.dig("public") == true &&
                      posts_by_id.key?(artifact[3]) &&
                      conversation.context.any? do |context_post|
                        context_post["id"] == artifact[3]
                      end,
                  artifact_id: artifact_id,
                  artifact_version: version,
                  share_key: conversation.share_key,
                  topic_id: conversation.target_id,
                  created_at: conversation.created_at,
                }
              end
          [conversation.id, cards]
        end
      end

      # A snapshot can outlive the post or topic it came from; those links stay
      # listed for revocation, but the profile must not present them as working.
      def viewable_post_ids(shares)
        post_ids = shares.filter_map { |share| share.ai_artifact&.post_id }.uniq
        return Set.new if post_ids.empty?

        posts_by_id = Post.where(id: post_ids).pluck(:id, :topic_id).to_h
        viewable_topic_ids = Topic.where(id: posts_by_id.values.uniq).pluck(:id).to_set
        posts_by_id
          .filter_map { |post_id, topic_id| post_id if viewable_topic_ids.include?(topic_id) }
          .to_set
      end
    end
  end
end
