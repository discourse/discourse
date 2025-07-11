# frozen_string_literal: true

module DiscourseTopicVoting
  module ListControllerExtension
    extend ActiveSupport::Concern

    prepended do
      before_action :ensure_discourse_topic_voting, only: %i[voted_by votes_feed]
      skip_before_action :ensure_logged_in, only: %i[voted_by votes_feed]
    end

    def voted_by
      list_opts = build_topic_list_options
      target_user = fetch_user_from_params(include_inactive: current_user.try(:staff?))
      list = generate_list_for("voted_by", target_user, list_opts)
      list.more_topics_url = url_for(construct_url_with(:next, list_opts))
      list.prev_topics_url = url_for(construct_url_with(:prev, list_opts))
      respond_with_list(list)
    end

    def votes_feed
      category_slug_path_with_id = params.require(:category_slug_path_with_id)

      @category = Category.find_by_slug_path_with_id(category_slug_path_with_id)
      @topic_list = TopicQuery.new(current_user, { category: @category.id }).list_votes

      render "list", formats: [:rss]
    end

    protected

    def ensure_discourse_topic_voting
      if !SiteSetting.topic_voting_enabled || !SiteSetting.topic_voting_show_votes_on_profile
        raise Discourse::NotFound
      end
    end
  end
end
