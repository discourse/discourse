#
#  SQL fragments used when querying a list of topics.
#
module TopicQuerySQL

  class << self

    # use the constants in conjuction with COALESCE to determine the order with regard to pinned
    # topics that have been cleared by the user. There might be a cleaner way to do this.
    def lowest_date
      "2010-01-01"
    end

    def highest_date
      "3000-01-01"
    end

    def order_by_category_sql(dir)
      "CASE WHEN categories.id = #{SiteSetting.uncategorized_category_id.to_i} THEN '' ELSE categories.name END #{dir}"
    end

    # If you've clearned the pin, use bumped_at, otherwise put it at the top
    def order_with_pinned_sql
      "CASE
        WHEN (COALESCE(topics.pinned_at, '#{lowest_date}') > COALESCE(tu.cleared_pinned_at, '#{lowest_date}'))
          THEN '#{highest_date}'
        ELSE topics.bumped_at
       END DESC"
    end

    # If you've clearned the pin, use bumped_at, otherwise put it at the top
    def order_nocategory_with_pinned_sql
      "CASE
        WHEN topics.pinned_globally and (COALESCE(topics.pinned_at, '#{lowest_date}') > COALESCE(tu.cleared_pinned_at, '#{lowest_date}'))
          THEN '#{highest_date}'
        ELSE topics.bumped_at
       END DESC"
    end

    def order_basic_bumped
      "CASE WHEN (topics.pinned_at IS NOT NULL) THEN 0 ELSE 1 END, topics.bumped_at DESC"
    end

    def order_nocategory_basic_bumped
      "CASE WHEN topics.pinned_globally and (topics.pinned_at IS NOT NULL) THEN 0 ELSE 1 END, topics.bumped_at DESC"
    end

    def order_top_for(score)
      "COALESCE(top_topics.#{score}, 0) DESC, topics.bumped_at DESC"
    end

    def order_top_with_pinned_category_for(score)
      # display pinned topics first
      "CASE WHEN COALESCE(topics.pinned_at, '#{lowest_date}') > COALESCE(tu.cleared_pinned_at, '#{lowest_date}') THEN 1 ELSE 0 END DESC,
       top_topics.#{score} DESC,
       topics.bumped_at DESC"
    end

  end
end
