# frozen_string_literal: true

module PostVoting
  module TopicViewExtension
    def self.prepended(base)
      base.attr_accessor(
        :comments,
        :comments_counts,
        :posts_user_voted,
        :comments_user_voted,
        :posts_voted_on,
      )

      base.const_set :PRELOAD_COMMENTS_COUNT, 5 unless base.const_defined?(:PRELOAD_COMMENTS_COUNT)

      if !base.const_defined?(:ACTIVITY_FILTER)
        # Change ORDER_BY_ACTIVITY_FILTER on the client side when the value here is changed
        base.const_set :ACTIVITY_FILTER, "activity"
      end
    end

    # Monkey patch core's method. In an ideal world, we wouldn't have to do this here but `TopicView` in core does not
    # yet properly support ordering posts in any other order except by `Post#sort_order` and several methods in
    # core's `TopicView` is strongly tied to the assumption that posts are always ordered by `Post#sort_order`. Fixing
    # core is hard and risky so we will just carry this monkey patch instead. There is also a small performance tradeoff
    # here in the following implementation. In PostgreSQL, we basically have to scan for every single posts in order
    # to figure out what the "row_number" for each post. From there, we can then properly fetch the window of posts
    # near a given post number.
    def filter_posts_near(post_number)
      return super if !post_voting_topic?

      post_number = 1 if post_number == 0

      cte_query = <<~SQL
      WITH rows AS (
        WITH posts AS (
          #{@filtered_posts.to_sql}
        )
        SELECT
          id,
          post_number,
          ROW_NUMBER() OVER () AS row_number
        FROM posts
      )
      SQL

      row_number, max_row_number = DB.query_single(<<~SQL)
      #{cte_query}
      SELECT
        row_number,
        (SELECT row_number FROM rows ORDER BY row_number DESC LIMIT 1) AS max_row_number
      FROM rows
      WHERE rows.post_number = #{post_number.to_i}
      SQL

      row_number = 1 if row_number.blank? # Post number does not exist so load from first post.

      posts_before = (@limit.to_f / 4).floor
      posts_before = 1 if posts_before.zero?
      posts_after = @limit - posts_before - 1

      range =
        # Lower boundary window
        if (row_number - posts_before) <= 0
          1..(@limit - (row_number - 1))
          # Upper boundary window
        elsif (max_row_number - row_number) < posts_after
          (max_row_number - @limit + 1)..max_row_number
          # Any other window in between.
        else
          (row_number - posts_before)..(row_number + posts_after)
        end

      post_ids = DB.query_single(<<~SQL)
      #{cte_query}
      SELECT
        id
      FROM rows
      WHERE rows.row_number IN (#{range.to_a.join(",")})
      SQL

      filter_posts_by_ids(post_ids)
    end

    def next_page
      return super if !post_voting_topic?

      @highest_post_number = @filtered_posts.last.post_number

      @next_page ||=
        if last_post && @highest_post_number && (@highest_post_number != last_post.post_number)
          @page + 1
        end
    end

    def post_voting_topic?
      topic.is_post_voting? && @filter != TopicView::ACTIVITY_FILTER
    end
  end
end
