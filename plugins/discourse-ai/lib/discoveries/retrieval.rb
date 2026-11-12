# frozen_string_literal: true

module DiscourseAi
  module Discoveries
    class Retrieval
      RRF_K = 60
      CANDIDATE_LIMIT = 50
      SYNTHESIS_LIMIT = 50
      EXCERPT_LIMIT = 1200
      SEMANTIC_PRIVATE_MESSAGE_FILTER = /(?:\A|\s)in:(?:messages|personal)(?=\s|\z)/i

      Result =
        Struct.new(:candidates, :scope_fallback, keyword_init: true) do
          def synthesis_candidates
            candidates.first(Retrieval::SYNTHESIS_LIMIT)
          end
        end

      def initialize(user:, lexical_retriever: nil, semantic_retriever: nil, external_sources: nil)
        @user = user
        @lexical_retriever = lexical_retriever || method(:lexical_sources)
        @semantic_retriever = semantic_retriever
        @external_sources = external_sources
      end

      # A scope filter narrows the forum's retrievals. When nothing in the forum
      # matches inside it, the whole site is searched instead and the result
      # says so. External sources are searched once, alongside both.
      def call(query, keyword_query: query, semantic_query: query, scope_filter: nil, locale: nil)
        external_searches =
          search_external_sources(query:, keyword_query:, semantic_query:, locale:)
        forum_rankings, forum_error =
          forum_rankings_with_error(query, keyword_query:, semantic_query:, scope_filter:)
        external_rankings = external_rankings(external_searches)
        # external results are still worth answering from when the forum's fail
        raise forum_error if forum_error && external_rankings.all?(&:empty?)

        result = result_from(forum_rankings + external_rankings)
        if scope_filter.present? && forum_search? && !forum_error &&
             result.candidates.all? { |candidate| ExternalSource.candidate?(candidate) }
          forum_rankings, forum_error =
            forum_rankings_with_error(query, keyword_query:, semantic_query:)
          raise forum_error if forum_error && external_rankings.all?(&:empty?)

          result = result_from(forum_rankings + external_rankings)
          result.scope_fallback = true
        end

        result
      end

      def self.explicit_filters?(query)
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

      def self.explicit_filters_except_private_messages?(query)
        explicit_filters?(query.to_s.gsub(SEMANTIC_PRIVATE_MESSAGE_FILTER, " "))
      end

      # Candidates were access-checked by the searches seconds earlier, so the
      # model's refs only need resolving; unknown or repeated ones are dropped.
      def sources_for(result, source_refs, limit:)
        candidates_by_ref =
          result.synthesis_candidates.index_by { |candidate| candidate["source_ref"] }

        Array(source_refs)
          .uniq
          .filter_map { |source_ref| candidates_by_ref[source_ref] }
          .first(limit)
      end

      private

      def result_from(rankings)
        candidates = with_metadata(reciprocal_rank_fusion(rankings))
        candidates =
          candidates.map.with_index do |candidate, index|
            candidate.merge("source_ref" => "source_#{index + 1}")
          end

        Result.new(candidates:)
      end

      def forum_rankings(query, keyword_query:, semantic_query:, scope_filter: nil)
        private_messages =
          DiscourseAi::Discoveries.private_message_query?(query) ||
            DiscourseAi::Discoveries.private_message_query?(keyword_query) ||
            DiscourseAi::Discoveries.private_message_query?(scope_filter)
        # embeddings describe whole topics, so they cannot narrow within one;
        # a topic is searched post by post instead
        topic_scope = scope_filter.to_s.start_with?("topic:")
        # a personal message is searched as one, or its posts are filtered out
        if topic_scope &&
             Topic.where(
               id: scope_filter.delete_prefix("topic:").to_i,
               archetype: Archetype.private_message,
             ).exists?
          private_messages = true
        end
        @per_post = topic_scope
        filters = [scope_filter, forced_filter(private_messages:)]
        scoped = ->(search_query) { [search_query, *filters].compact_blank.join(" ") }

        explicit_query = self.class.explicit_filters_except_private_messages?(query)
        semantic =
          semantic_search? && !explicit_query && !topic_scope && semantic_query.present? &&
            !self.class.explicit_filters_except_private_messages?(keyword_query)

        searches = []
        if keyword_search?
          searches << [@lexical_retriever, scoped.(explicit_query ? query : keyword_query)]
        end
        searches << [semantic_retriever(private_messages:), scoped.(semantic_query)] if semantic

        return [] if searches.empty?
        return [retrieve(*searches.first)] if searches.length == 1

        retrieve_in_parallel(searches)
      end

      def forum_rankings_with_error(...)
        [forum_rankings(...), nil]
      rescue StandardError => error
        Rails.logger.warn(
          "Discourse AI Discoveries continued without forum retrieval: #{error.class}",
        )
        [[], error]
      end

      def keyword_search?
        SiteSetting.ai_ask_ai_keyword_search_enabled
      end

      def semantic_search?
        SiteSetting.ai_ask_ai_semantic_search_enabled && DiscourseAi::Embeddings.enabled?
      end

      def forum_search?
        keyword_search? || semantic_search?
      end

      # Set by the site rather than the reader, so unlike a scope these are
      # never dropped to widen a search that found nothing.
      def forced_filter(private_messages:)
        filters = []
        if (max_age_days = SiteSetting.ai_ask_ai_search_max_age_days).positive?
          filters << "after:#{max_age_days.days.ago.to_date.iso8601}"
        end
        # personal messages have no category, so limiting by one would hide them all
        category_ids = SiteSetting.ai_ask_ai_search_categories_map
        if !private_messages && category_ids.present?
          filters << "categories:#{category_ids.join(",")}"
        end
        filters.join(" ").presence
      end

      def search_external_sources(**queries)
        sources = @external_sources || ExternalSource.configured(user: @user)
        return [] if sources.empty?

        database = RailsMultisite::ConnectionManagement.current_db
        deadline =
          Process.clock_gettime(Process::CLOCK_MONOTONIC) +
            SiteSetting.ai_ask_ai_external_sources_timeout
        sources.filter_map do |source|
          if !ExternalSource.claim_slot
            skip_external_source(source, :busy)
            next
          end

          thread =
            Thread.new do
              RailsMultisite::ConnectionManagement.with_connection(database) do
                [source.call(**queries), nil]
              rescue StandardError => error
                [[], error]
              end
            ensure
              ExternalSource.release_slot
            end
          [source, thread, deadline]
        end
      end

      # A source still running at the deadline is not waited for. It runs on
      # until the tool runner's own limits end it, holding its slot.
      def external_rankings(searches)
        searches.filter_map do |source, thread, deadline|
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          if thread.join([remaining, 0].max).nil?
            skip_external_source(source, :timed_out)
            next
          end

          results, error = thread.value
          if error
            skip_external_source(source, :failed, error.class)
            next
          end

          source.record_outcome(:succeeded)
          results
        end
      end

      def skip_external_source(source, outcome, reason = outcome)
        source.record_outcome(outcome)
        Rails.logger.warn(
          "Discourse AI Discoveries skipped external source #{source.name}: #{reason}",
        )
      end

      def lexical_sources(query)
        guardian = Guardian.new(@user)
        results = ::Search.execute(query, search_type: :full_page, guardian:)
        return [] if results.nil?

        seen_topic_ids = Set.new
        posts = Array(results.posts)
        ActiveRecord::Associations::Preloader.new(records: posts, associations: :topic).call

        posts
          .filter_map do |post|
            next if !@per_post && seen_topic_ids.include?(post.topic_id)

            seen_topic_ids << post.topic_id
            source_from_post(post, excerpt: results.blurb(post, scope: guardian))
          end
          .first(CANDIDATE_LIMIT)
      end

      def retrieve_in_parallel(searches)
        database = RailsMultisite::ConnectionManagement.current_db
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
            candidate =
              fused[source["topic_id"] || source.fetch("url")] ||= source.merge(
                "rrf_score" => 0.0,
                "retrievals" => [],
              )
            if source["post_id"]
              passages = candidate["passages"] ||= []
              if passages.none? { |passage| passage["post_id"] == source["post_id"] }
                passages << passage_from_source(source)
              end
            end
            candidate["rrf_score"] += 1.0 / (RRF_K + index + 1)
            candidate["retrievals"] << { "ranking" => ranking_index + 1, "rank" => index + 1 }
          end
        end

        # on a tie the forum's topics come first, in a stable order
        fused.values.sort_by do |candidate|
          [
            -candidate.fetch("rrf_score"),
            candidate["topic_id"] || Float::INFINITY,
            candidate["url"].to_s,
          ]
        end
      end

      def passage_from_source(source)
        source.slice("post_id", "post_number", "url", "excerpt", "post_updated_at")
      end

      # The forum's retrievers search with the user's guardian, so candidates only
      # need the metadata synthesis and the sources list show.
      def with_metadata(candidates)
        candidates = candidates.first(CANDIDATE_LIMIT)
        posts =
          Post
            .where(id: candidates.pluck("post_id").compact)
            .includes(:user, topic: [{ category: :parent_category }, :tags])
            .index_by(&:id)
        topic_ids = posts.values.map(&:topic_id).uniq
        accepted_answers = accepted_answers_by_topic_id(topic_ids)
        endorsed_replies = endorsed_replies_by_topic_id(topic_ids - accepted_answers.keys)
        hidden_tags = DiscourseTagging.hidden_tag_names if SiteSetting.tagging_enabled

        candidates.filter_map do |candidate|
          next candidate if ExternalSource.candidate?(candidate)

          post = posts[candidate.fetch("post_id")]
          topic = post&.topic
          next if topic.nil?

          search_metadata =
            DiscourseAi::Utils::Search.format_row(
              topic:,
              post:,
              hidden_tags:,
              excerpt: plain_text(candidate["excerpt"]),
            ).stringify_keys

          candidate =
            candidate.merge(
              search_metadata,
              "category_id" => topic.category_id,
              "username" => post.user&.username,
              "name" => SiteSetting.enable_names? ? post.user&.name : nil,
              "avatar_template" => post.user&.avatar_template,
              "author_is_staff" => post.user&.staff? || false,
              "is_topic_op" => post.post_number == 1,
              "topic_bumped_at" => topic.bumped_at&.iso8601,
            )
          if (answers = accepted_answers[topic.id])
            with_answers(candidate, answers).merge("solved" => true)
          elsif (replies = endorsed_replies[topic.id])
            with_answers(candidate, replies)
          else
            candidate
          end
        end
      end

      def accepted_answers_by_topic_id(topic_ids)
        return {} if !defined?(DiscourseSolved) || !SiteSetting.solved_enabled || topic_ids.empty?

        guardian = Guardian.new(@user)
        Post
          .where(
            id:
              DiscourseSolved::TopicAnswer
                .joins(:solved_topic)
                .where(discourse_solved_solved_topics: { topic_id: topic_ids })
                .select(:answer_post_id),
            post_type: Post.types[:regular],
            hidden: false,
          )
          .includes(:topic)
          .select { |post| guardian.can_see_post?(post) }
          .group_by(&:topic_id)
      end

      # The best answer an unsolved topic has is a reply its author liked, the
      # author's own liked follow-up after others replied, or a reply a member of
      # the groups the site trusts liked, in that order. One per topic.
      def endorsed_replies_by_topic_id(topic_ids)
        group_ids = SiteSetting.ai_ask_ai_endorsed_reply_groups_map
        return {} if group_ids.empty? || topic_ids.empty?

        params = {
          topic_ids:,
          group_ids:,
          # every like comes from a logged-in user
          any_liker:
            group_ids.intersect?(
              [Group::AUTO_GROUPS[:everyone], Group::AUTO_GROUPS[:logged_in_users]],
            ),
          like: PostActionType::LIKE_POST_ACTION_ID,
          regular: Post.types[:regular],
        }
        post_ids = DB.query_single(<<~SQL, **params)
          SELECT post_id
          FROM (
            SELECT
              posts.id AS post_id,
              ROW_NUMBER() OVER (
                PARTITION BY posts.topic_id
                ORDER BY
                  BOOL_OR(post_actions.user_id = topics.user_id) DESC,
                  posts.user_id = topics.user_id DESC,
                  posts.like_count DESC,
                  posts.post_number
              ) AS rank
            FROM posts
            JOIN topics ON topics.id = posts.topic_id
            JOIN post_actions
              ON post_actions.post_id = posts.id
              AND post_actions.post_action_type_id = :like
              AND post_actions.deleted_at IS NULL
            WHERE posts.topic_id IN (:topic_ids)
              AND posts.post_number > 1
              AND posts.post_type = :regular
              AND NOT posts.hidden
              AND posts.deleted_at IS NULL
              AND (
                post_actions.user_id = topics.user_id
                OR :any_liker
                OR post_actions.user_id IN (
                  SELECT user_id FROM group_users WHERE group_id IN (:group_ids)
                )
                OR (
                  posts.user_id = topics.user_id
                  AND EXISTS (
                    SELECT 1
                    FROM posts earlier
                    WHERE earlier.topic_id = posts.topic_id
                      AND earlier.post_number BETWEEN 2 AND posts.post_number - 1
                      AND earlier.user_id <> topics.user_id
                      AND earlier.post_type = :regular
                      AND earlier.deleted_at IS NULL
                  )
                )
              )
            GROUP BY posts.id, topics.id
          ) endorsed
          WHERE rank = 1
        SQL
        return {} if post_ids.empty?

        guardian = Guardian.new(@user)
        Post
          .where(id: post_ids)
          .includes(:topic)
          .select { |post| guardian.can_see_post?(post) }
          .group_by(&:topic_id)
      end

      # Retrieval mostly matches the question in a topic's first post, so an
      # answer would rarely reach the model unless it is added.
      def with_answers(candidate, answers)
        passages = Array(candidate["passages"]).dup
        answers.each do |answer|
          if (index = passages.index { |passage| passage["post_id"] == answer.id })
            passages[index] = passages[index].merge("answer" => true)
          else
            passages << passage_from_source(source_from_post(answer, excerpt: answer.cooked)).merge(
              "answer" => true,
            )
          end
        end

        candidate.merge("passages" => passages)
      end

      def plain_text(value)
        Nokogiri::HTML5.fragment(value.to_s).text.squish.first(EXCERPT_LIMIT)
      end
    end
  end
end
