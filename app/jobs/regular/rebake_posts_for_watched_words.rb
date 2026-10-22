# frozen_string_literal: true

module Jobs
  class RebakePostsForWatchedWords < ::Jobs::Base
    BATCH_SIZE = 100
    SCAN_WINDOW_SIZE = 1_000
    PATTERN_BATCH_SIZE = 50

    sidekiq_options queue: "ultra_low"

    def self.enqueue_for(watched_words)
      return if SiteSetting.watched_words_regular_expressions?

      words =
        Array(watched_words)
          .select(&:requires_post_rebake?)
          .map(&:word)
          .reject { |word| word.include?("*") }
          .uniq

      Jobs.enqueue(self, words:) if words.present?
    end

    def execute(args)
      words = Array(args[:words]).select(&:present?).uniq
      return if words.empty? || SiteSetting.watched_words_regular_expressions?

      after_post_id = args[:after_post_id].to_i
      max_post_id = args[:max_post_id].to_i
      max_post_id = Post.maximum(:id).to_i if max_post_id.zero?
      return if max_post_id.zero? || after_post_id >= max_post_id

      scan_end_post_id = [after_post_id + SCAN_WINDOW_SIZE, max_post_id].min
      post_ids = matching_post_ids(words, after_post_id:, scan_end_post_id:)
      Post.where(id: post_ids).find_each { |post| post.rebake!(priority: :ultra_low) }

      next_post_id =
        if post_ids.size == BATCH_SIZE && post_ids.last < scan_end_post_id
          post_ids.last
        else
          scan_end_post_id
        end

      if next_post_id < max_post_id
        Jobs.enqueue(self.class, words:, after_post_id: next_post_id, max_post_id:)
      end
    end

    private

    def matching_post_ids(words, after_post_id:, scan_end_post_id:)
      words
        .each_slice(PATTERN_BATCH_SIZE)
        .flat_map do |word_batch|
          patterns = word_batch.map { |word| "%#{ActiveRecord::Base.sanitize_sql_like(word)}%" }
          conditions = Array.new(patterns.size, "posts.raw ILIKE ?").join(" OR ")

          Post
            .where(["(#{conditions})", *patterns])
            .where(id: (after_post_id + 1)..scan_end_post_id)
            .order(:id)
            .limit(BATCH_SIZE)
            .pluck(:id)
        end
        .uniq
        .sort
        .first(BATCH_SIZE)
    end
  end
end
