# frozen_string_literal: true

module DiscourseMcp
  # A TopicQuery whose lists leave out the topics the content policy restricts.
  #
  # Lists built through TopicQuery#create_list are narrowed in SQL before paging,
  # so a page never comes back short because restricted topics were dropped
  # after the query ran. A list method that doesn't go through create_list
  # returns its topics unnarrowed, so tools only call the ones that do.
  class PolicyTopicQuery < ::TopicQuery
    # @param user [User]
    # @param options [Hash] TopicQuery options. `guardian` defaults to the user's.
    # @param content_policy [ContentPolicy]
    def initialize(user, options = {}, content_policy:)
      @content_policy = content_policy
      super(user, { guardian: user&.guardian }.merge(options))
    end

    def create_list(filter, options = {}, topics = nil)
      super(filter, options, topics) do |relation|
        relation = yield(relation) if block_given?
        @content_policy.scope_topics(relation)
      end
    end

    private

    # Category selectors in a query string treat restricted categories as
    # missing, so a selector can't reveal that one exists.
    def build_topics_filter(scope, **options)
      super(scope, hidden_category_ids: @content_policy.restricted_category_ids, **options)
    end
  end
end
