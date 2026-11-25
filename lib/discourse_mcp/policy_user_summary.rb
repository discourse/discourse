# frozen_string_literal: true

module DiscourseMcp
  # A UserSummary that leaves out what the content policy restricts.
  #
  # Topics, replies, links and categories are narrowed in SQL. The like and reply
  # rankings count interactions across every topic, so they're left out while a
  # rule narrows topics: no per-topic filter can make those totals safe.
  class PolicyUserSummary < ::UserSummary
    # @param user [User]
    # @param guardian [Guardian]
    # @param content_policy [ContentPolicy]
    def initialize(user, guardian, content_policy:)
      @content_policy = content_policy
      super(user, guardian)
    end

    def topics
      @content_policy.scope_topics(super)
    end

    def links
      condition = @content_policy.topic_condition("topics")
      condition ? super.where(condition) : super
    end

    def most_liked_by_users
      @content_policy.restricts_forum? ? [] : super
    end

    def most_liked_users
      @content_policy.restricts_forum? ? [] : super
    end

    def most_replied_to_users
      @content_policy.restricts_forum? ? [] : super
    end

    def top_categories
      return super if !@content_policy.restricts_forum?

      # The topic counts in the summary come from an unnarrowed query, so the
      # categories are kept but their counts are left out.
      super
        .select { |category| @content_policy.allows_category_id?(category[:id]) }
        .each do |category|
          category.topic_count = nil
          category.post_count = nil
          category.parent_category_id =
            @content_policy.redact_category_id(category.parent_category_id)
        end
    end

    protected

    def post_query
      condition = @content_policy.topic_condition("topics")
      condition ? super.where(condition) : super
    end
  end
end
