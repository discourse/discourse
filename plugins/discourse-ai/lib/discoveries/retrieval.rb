# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    class Retrieval
      RRF_K = 60
      CANDIDATE_LIMIT = 50
      SYNTHESIS_LIMIT = 50
      SELECTED_SOURCE_LIMIT = 6
      EXCERPT_LIMIT = 1200
      SEMANTIC_PRIVATE_MESSAGE_FILTER = /(?:\A|\s)in:(?:messages|personal)(?=\s|\z)/i

      Result =
        Struct.new(:candidates, :private_messages, keyword_init: true) do
          def synthesis_candidates
            candidates.first(Retrieval::SYNTHESIS_LIMIT)
          end
        end

      class << self
        def explicit_filters?(query)
          query
            .to_s
            .scan(/(([^" \t\n\x0B\f\r]+)?(("[^"]+")?))/)
            .filter_map { |word,| word.presence }
            .any? do |word|
              cleaned = word.delete("\"'")
              direct_filter =
                cleaned.match?(
                  /\A(?:[lr]|t|order:\w+|in:title|topic:\d+|in:all(?:-posts)?|include:(?:invisible|unlisted)|personal_messages:\S+)\z/i,
                )

              direct_filter ||
                Search.advanced_filters.values.any? do |options|
                  options[:enabled].call && cleaned.match?(options[:case_insensitive_matcher])
                end
            end
        end

        def explicit_filters_except_private_messages?(query)
          explicit_filters?(query.to_s.gsub(SEMANTIC_PRIVATE_MESSAGE_FILTER, " "))
        end
      end

      def initialize(user:, lexical_retriever: nil, semantic_retriever: nil)
        @user = user
        @guardian = Guardian.new(user)
        @lexical_retriever = lexical_retriever || method(:lexical_sources)
        @semantic_retriever = semantic_retriever
      end

      def call(query, keyword_query: query, semantic_query: query)
        private_messages =
          DiscourseAi::Discoveries.private_message_query?(query) ||
            DiscourseAi::Discoveries.private_message_query?(keyword_query)

        rankings =
          if self.class.explicit_filters_except_private_messages?(query)
            [retrieve(@lexical_retriever, query)]
          elsif semantic_query.blank? ||
                self.class.explicit_filters_except_private_messages?(keyword_query)
            [retrieve(@lexical_retriever, keyword_query)]
          else
            retrieve_in_parallel(keyword_query, semantic_query, private_messages:)
          end
        candidates = reciprocal_rank_fusion(rankings)
        candidates = revalidate_and_limit(candidates, private_messages:)
        candidates =
          candidates.map.with_index do |candidate, index|
            candidate.merge("source_ref" => "source_#{index + 1}")
          end

        Result.new(candidates:, private_messages:)
      end

      def validated_sources(result, source_refs)
        source_refs = Array(source_refs)
        return [] if source_refs.empty? || source_refs.length > SELECTED_SOURCE_LIMIT
        return [] if source_refs.any? { |source_ref| !source_ref.is_a?(String) }
        return [] if source_refs.uniq.length != source_refs.length

        candidates_by_ref =
          result.synthesis_candidates.index_by { |candidate| candidate["source_ref"] }
        selected = source_refs.filter_map { |source_ref| candidates_by_ref[source_ref] }
        return [] if selected.length != source_refs.length

        revalidated = revalidate_and_limit(selected, private_messages: result.private_messages)
        return [] if revalidated.length != selected.length

        revalidated
      end

      private

      def lexical_sources(query)
        guardian = Guardian.new(@user)
        results = ::Search.execute(query, search_type: :full_page, guardian:)
        return [] if results.nil?

        seen_topic_ids = Set.new
        posts = Array(results.posts)
        ActiveRecord::Associations::Preloader.new(records: posts, associations: :topic).call

        posts
          .filter_map do |post|
            next if seen_topic_ids.include?(post.topic_id)

            seen_topic_ids << post.topic_id
            source_from_post(post, excerpt: results.blurb(post, scope: guardian))
          end
          .first(CANDIDATE_LIMIT)
      end

      def retrieve_in_parallel(keyword_query, semantic_query, private_messages:)
        database = RailsMultisite::ConnectionManagement.current_db
        searches = [
          [@lexical_retriever, keyword_query],
          [semantic_retriever(private_messages:), semantic_query],
        ]
        threads =
          searches.map do |retriever, search_query|
            Thread.new do
              RailsMultisite::ConnectionManagement.with_connection(database) do
                retrieve_with_error(retriever, search_query)
              end
            end
          end
        results = threads.map(&:value)
        errors = results.filter_map(&:last)
        raise errors.first if errors.length == searches.length

        if errors.present?
          Rails.logger.warn(
            "Discourse AI Discoveries continued after one retrieval method failed: #{errors.first.class}",
          )
        end

        results.map(&:first)
      ensure
        threads&.each { |thread| thread.join if thread.alive? }
      end

      def retrieve(retriever, query)
        result, error = retrieve_with_error(retriever, query)
        raise error if error

        result
      end

      def retrieve_with_error(retriever, query)
        [Array(retriever.call(query)), nil]
      rescue StandardError => error
        [[], error]
      end

      def semantic_retriever(private_messages:)
        @semantic_retriever || ->(query) { semantic_sources(query, private_messages:) }
      end

      def semantic_sources(query, private_messages:)
        guardian = Guardian.new(@user)
        DiscourseAi::Embeddings::SemanticSearch
          .new(guardian)
          .search_for_topics(query, 1, hyde: false, private_messages:)
          .includes(:topic)
          .to_a
          .uniq(&:topic_id)
          .first(CANDIDATE_LIMIT)
          .map { |post| source_from_post(post) }
      end

      def source_from_post(post, excerpt: nil)
        {
          "topic_id" => post.topic_id,
          "post_id" => post.id,
          "post_number" => post.post_number,
          "title" => post.topic.title,
          "url" => post.relative_url,
          "excerpt" => plain_text(excerpt.presence || post.excerpt),
          "post_updated_at" => post.updated_at.iso8601(6),
        }
      end

      def reciprocal_rank_fusion(rankings)
        fused = {}
        rankings.each_with_index do |ranking, ranking_index|
          ranking.each_with_index do |source, index|
            topic_id = source.fetch("topic_id")
            candidate =
              fused[topic_id] ||= source.merge(
                "rrf_score" => 0.0,
                "retrievals" => [],
                "passages" => [passage_from_source(source)],
              )
            if candidate["passages"].none? { |passage| passage["post_id"] == source["post_id"] }
              candidate["passages"] << passage_from_source(source)
            end
            candidate["rrf_score"] += 1.0 / (RRF_K + index + 1)
            candidate["retrievals"] << { "ranking" => ranking_index + 1, "rank" => index + 1 }
          end
        end

        fused.values.sort_by do |candidate|
          [-candidate.fetch("rrf_score"), candidate.fetch("topic_id")]
        end
      end

      def passage_from_source(source)
        source.slice("post_id", "post_number", "url", "excerpt", "post_updated_at")
      end

      def revalidate_and_limit(candidates, private_messages: false)
        post_ids =
          candidates.flat_map do |candidate|
            candidate.fetch("passages", [candidate]).map { |passage| passage.fetch("post_id") }
          end
        posts =
          Post
            .where(id: post_ids, deleted_at: nil)
            .includes(:user, topic: [{ category: :parent_category }, :tags])
            .index_by(&:id)
        hidden_tags = DiscourseTagging.hidden_tag_names if SiteSetting.tagging_enabled
        private_message_topic_ids = Set.new
        if private_messages && @user
          private_message_topic_ids =
            Topic
              .private_messages_for_user(@user)
              .where(id: candidates.pluck("topic_id"))
              .pluck(:id)
              .to_set
        end
        visible_post_types = Topic.visible_post_types(@user)

        candidates
          .filter_map do |candidate|
            post = posts[candidate.fetch("post_id")]
            topic = post&.topic
            next if topic.nil? || topic.id != candidate.fetch("topic_id")
            allowed_archetype =
              if private_messages
                topic.archetype == Archetype.private_message
              else
                topic.archetype == Archetype.default
              end
            next if !allowed_archetype
            next if topic.deleted_at? || !topic.visible?
            if topic.private_message?
              next if !private_message_topic_ids.include?(topic.id)
              next if post.hidden? || !visible_post_types.include?(post.post_type)
            else
              next if !@guardian.can_see?(post)
            end
            if candidate["post_updated_at"] &&
                 candidate["post_updated_at"] != post.updated_at.iso8601(6)
              next
            end
            if candidate["topic_updated_at"] &&
                 candidate["topic_updated_at"] != topic.updated_at.iso8601(6)
              next
            end

            candidate_passages = candidate.fetch("passages", [candidate])
            passages =
              candidate_passages.filter_map do |passage|
                passage_post = posts[passage.fetch("post_id")]
                next if passage_post.nil? || passage_post.topic_id != topic.id
                if topic.private_message?
                  if passage_post.hidden? || !visible_post_types.include?(passage_post.post_type)
                    next
                  end
                elsif !@guardian.can_see?(passage_post)
                  next
                end
                if passage["post_updated_at"] &&
                     passage["post_updated_at"] != passage_post.updated_at.iso8601(6)
                  next
                end

                passage_from_source(
                  passage.merge(
                    "post_number" => passage_post.post_number,
                    "url" => passage_post.relative_url,
                    "post_updated_at" => passage_post.updated_at.iso8601(6),
                  ),
                )
              end
            next if passages.length != candidate_passages.length

            search_metadata =
              DiscourseAi::Utils::Search.format_row(
                topic:,
                post:,
                hidden_tags:,
                excerpt: plain_text(candidate["excerpt"]),
              ).stringify_keys

            candidate.merge(
              search_metadata,
              "category_id" => topic.category_id,
              "username" => post.user&.username,
              "name" => post.user&.name,
              "avatar_template" => post.user&.avatar_template,
              "author_is_staff" => post.user&.staff? || false,
              "is_topic_op" => post.post_number == 1,
              "passages" => passages,
              "post_updated_at" => post.updated_at.iso8601(6),
              "topic_updated_at" => topic.updated_at.iso8601(6),
            )
          end
          .first(CANDIDATE_LIMIT)
      end

      def plain_text(value)
        Nokogiri::HTML5.fragment(value.to_s).text.squish.first(EXCERPT_LIMIT)
      end
    end
  end
end
