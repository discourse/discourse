# frozen_string_literal: true

module Jobs
  class RebakePostsForWatchedWords < ::Jobs::Base
    BATCH_SIZE = 100

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
      return if max_post_id.zero?

      posts = matching_posts(words, after_post_id:, max_post_id:)
      posts.each { |post| post.rebake!(priority: :ultra_low) }

      if posts.size == BATCH_SIZE && posts.last.id < max_post_id
        Jobs.enqueue(self.class, words:, after_post_id: posts.last.id, max_post_id:)
      end
    end

    private

    def matching_posts(words, after_post_id:, max_post_id:)
      patterns = words.map { |word| "%#{ActiveRecord::Base.sanitize_sql_like(word)}%" }
      conditions = Array.new(patterns.size, "posts.raw ILIKE ?").join(" OR ")

      Post
        .where(["(#{conditions})", *patterns])
        .where(id: (after_post_id + 1)..max_post_id)
        .order(:id)
        .limit(BATCH_SIZE)
        .to_a
    end
  end
end
