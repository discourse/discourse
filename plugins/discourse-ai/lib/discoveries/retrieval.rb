# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    class Retrieval
      RRF_K = 60
      CANDIDATE_LIMIT = 30
      SYNTHESIS_LIMIT = 20
      SELECTED_SOURCE_LIMIT = 6
      EXCERPT_LIMIT = 1200

      Result =
        Struct.new(:candidates, keyword_init: true) do
          def synthesis_candidates
            candidates.first(Retrieval::SYNTHESIS_LIMIT)
          end

          def source_for(source_ref)
            candidates.find { |candidate| candidate.fetch("source_ref") == source_ref }
          end
        end

      def initialize(user:, lexical_retriever: nil, semantic_retriever: nil)
        @guardian = Guardian.new(user)
        @lexical_retriever = lexical_retriever || method(:lexical_sources)
        @semantic_retriever = semantic_retriever || method(:semantic_sources)
      end

      def call(query)
        return Result.new(candidates: []) if DiscourseAi::Discoveries.private_message_query?(query)

        rankings = [@lexical_retriever.call(query)]
        rankings << @semantic_retriever.call(query) if !explicit_filters?(query)
        candidates = reciprocal_rank_fusion(rankings)
        candidates = revalidate_and_limit(candidates)
        candidates =
          candidates.map.with_index do |candidate, index|
            candidate.merge("source_ref" => "source_#{index + 1}")
          end

        Result.new(candidates:)
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

        revalidated = revalidate_and_limit(selected)
        return [] if revalidated.length != selected.length

        revalidated
      end

      private

      def lexical_sources(query)
        results = ::Search.execute(query, search_type: :full_page, guardian: @guardian)
        return [] if results.nil?

        seen_topic_ids = Set.new
        posts = Array(results.posts)
        ActiveRecord::Associations::Preloader.new(records: posts, associations: :topic).call

        posts
          .filter_map do |post|
            next if seen_topic_ids.include?(post.topic_id)

            seen_topic_ids << post.topic_id
            source_from_post(post, excerpt: results.blurb(post, scope: @guardian))
          end
          .first(CANDIDATE_LIMIT)
      end

      def explicit_filters?(query)
        query
          .to_s
          .scan(/(([^" \t\n\x0B\f\r]+)?(("[^"]+")?))/)
          .filter_map { |word,| word.presence }
          .any? do |word|
            cleaned = word.delete("\"'")
            direct_filter =
              cleaned.match?(
                /\A(?:[lr]|t|order:\w+|in:title|topic:\d+|in:all(?:-posts)?|include:(?:invisible|unlisted))\z/i,
              )

            direct_filter ||
              Search.advanced_filters.values.any? do |options|
                options[:enabled].call && cleaned.match?(options[:case_insensitive_matcher])
              end
          end
      end

      def semantic_sources(query)
        DiscourseAi::Embeddings::SemanticSearch
          .new(@guardian)
          .search_for_topics(query, 1, hyde: false)
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
          "title" => post.topic.title,
          "url" => post.relative_url,
          "excerpt" => plain_text(excerpt.presence || post.excerpt),
        }
      end

      def reciprocal_rank_fusion(rankings)
        fused = {}
        rankings.each_with_index do |ranking, ranking_index|
          ranking.each_with_index do |source, index|
            topic_id = source.fetch("topic_id")
            candidate = fused[topic_id] ||= source.merge("rrf_score" => 0.0, "retrievals" => [])
            candidate["rrf_score"] += 1.0 / (RRF_K + index + 1)
            candidate["retrievals"] << { "ranking" => ranking_index + 1, "rank" => index + 1 }
          end
        end

        fused.values.sort_by do |candidate|
          [-candidate.fetch("rrf_score"), candidate.fetch("topic_id")]
        end
      end

      def revalidate_and_limit(candidates)
        post_ids = candidates.map { |candidate| candidate.fetch("post_id") }
        posts = Post.where(id: post_ids, deleted_at: nil).includes(topic: :category).index_by(&:id)

        candidates
          .filter_map do |candidate|
            post = posts[candidate.fetch("post_id")]
            topic = post&.topic
            next if topic.nil? || topic.id != candidate.fetch("topic_id")
            next if topic.archetype != Archetype.default || topic.deleted_at? || !topic.visible?
            next if !@guardian.can_see?(post)
            if candidate["post_updated_at"] &&
                 candidate["post_updated_at"] != post.updated_at.iso8601(6)
              next
            end
            if candidate["topic_updated_at"] &&
                 candidate["topic_updated_at"] != topic.updated_at.iso8601(6)
              next
            end

            candidate.merge(
              "title" => topic.title,
              "url" => post.relative_url,
              "excerpt" => plain_text(candidate["excerpt"]),
              "category" => topic.category&.name,
              "topic_replies" => [topic.posts_count - 1, 0].max,
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
