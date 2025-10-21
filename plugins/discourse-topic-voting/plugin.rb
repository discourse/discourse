# frozen_string_literal: true

# name: discourse-topic-voting
# about: Adds the ability to vote on topics in a specified category.
# meta_topic_id: 40121
# version: 0.5
# author: Joe Buhlig joebuhlig.com, Sam Saffron
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-topic-voting

register_asset "stylesheets/common/topic-voting.scss"
register_asset "stylesheets/desktop/topic-voting.scss", :desktop
register_asset "stylesheets/mobile/topic-voting.scss", :mobile

enabled_site_setting :topic_voting_enabled

Discourse.top_menu_items.push(:votes)
Discourse.anonymous_top_menu_items.push(:votes)
Discourse.filters.push(:votes)
Discourse.anonymous_filters.push(:votes)

module ::DiscourseTopicVoting
  PLUGIN_NAME = "discourse-topic-voting"
end

require_relative "lib/discourse_topic_voting/engine"

after_initialize do
  reloadable_patch do
    CategoriesController.prepend(DiscourseTopicVoting::CategoriesControllerExtension)
    Category.prepend(DiscourseTopicVoting::CategoryExtension)
    ListController.prepend(DiscourseTopicVoting::ListControllerExtension)
    Topic.prepend(DiscourseTopicVoting::TopicExtension)
    TopicQuery.prepend(DiscourseTopicVoting::TopicQueryExtension)
    User.prepend(DiscourseTopicVoting::UserExtension)
    WebHook.prepend(DiscourseTopicVoting::WebHookExtension)
  end

  add_to_serializer(:post, :can_vote, include_condition: -> { object.post_number == 1 }) do
    object.topic&.can_vote?
  end

  add_to_serializer(:topic_view, :can_vote) { object.topic.can_vote? }
  add_to_serializer(:topic_view, :vote_count) { object.topic.vote_count }
  add_to_serializer(:topic_view, :user_voted) do
    scope.user ? object.topic.user_voted?(scope.user) : false
  end

  if TopicQuery.respond_to?(:results_filter_callbacks)
    TopicQuery.results_filter_callbacks << ->(_type, result, user, options) do
      result = result.includes(:topic_vote_count)

      if user
        result =
          result.select(
            "topics.*, COALESCE((SELECT 1 FROM topic_voting_votes WHERE user_id = #{user.id} AND topic_id = topics.id), 0) AS current_user_voted",
          )

        if options[:state] == "my_votes"
          result =
            result.joins(
              "INNER JOIN topic_voting_votes ON topic_voting_votes.topic_id = topics.id AND topic_voting_votes.user_id = #{user.id}",
            )
        end
      end

      if options[:order] == "votes"
        sort_dir = (options[:ascending] == "true") ? "ASC" : "DESC"
        result =
          result.joins(
            "LEFT JOIN topic_voting_topic_vote_count ON topic_voting_topic_vote_count.topic_id = topics.id",
          ).reorder(
            "COALESCE(topic_voting_topic_vote_count.votes_count,'0')::integer #{sort_dir}, topics.bumped_at DESC",
          )
      end

      result
    end
  end

  register_category_custom_field_type("enable_topic_voting", :boolean)
  add_to_serializer(:category, :custom_fields, respect_plugin_enabled: false) do
    return object.custom_fields if !SiteSetting.topic_voting_enabled

    object.custom_fields.merge(
      enable_topic_voting:
        DiscourseTopicVoting::CategorySetting.find_by(category_id: object.id).present?,
    )
  end

  add_to_serializer(:topic_list_item, :vote_count, include_condition: -> { object.can_vote? }) do
    object.vote_count
  end
  add_to_serializer(:topic_list_item, :can_vote, include_condition: -> { object.regular? }) do
    object.can_vote?
  end
  add_to_serializer(:topic_list_item, :user_voted, include_condition: -> { object.can_vote? }) do
    object.user_voted?(scope.user) if scope.user
  end
  add_to_serializer(
    :basic_category,
    :can_vote,
    include_condition: -> { Category.can_vote?(object.id) },
  ) { true }

  register_search_advanced_filter(/^min_vote_count:(\d+)$/) do |posts, match|
    posts.where(
      "(SELECT votes_count FROM topic_voting_topic_vote_count WHERE topic_voting_topic_vote_count.topic_id = posts.topic_id) >= ?",
      match.to_i,
    )
  end

  register_search_advanced_order(:votes) do |posts|
    posts.reorder(
      "COALESCE((SELECT dvtvc.votes_count FROM topic_voting_topic_vote_count dvtvc WHERE dvtvc.topic_id = topics.id), 0) DESC",
    )
  end

  add_to_serializer(:current_user, :votes_exceeded) { object.reached_voting_limit? }
  add_to_serializer(:current_user, :votes_count) { object.vote_count }
  add_to_serializer(:current_user, :votes_left) { [object.vote_limit - object.vote_count, 0].max }

  filter_order_votes = ->(scope, order_direction, _guardian) do
    scope.joins(:topic_vote_count).order(
      "COALESCE(topic_voting_topic_vote_count.votes_count, 0)::integer #{order_direction}",
    )
  end

  add_filter_custom_filter("order:votes", &filter_order_votes)

  on(:topic_status_updated) do |topic, status, enabled|
    next if topic.trashed?
    next if %w[closed autoclosed archived].exclude?(status)

    if enabled
      Jobs.enqueue(Jobs::DiscourseTopicVoting::VoteRelease, topic_id: topic.id)
    else
      is_closing_unarchived = %w[closed autoclosed].include?(status) && !topic.archived
      is_archiving_open = status == "archived" && !topic.closed

      if is_closing_unarchived || is_archiving_open
        Jobs.enqueue(Jobs::DiscourseTopicVoting::VoteReclaim, topic_id: topic.id)
      end
    end
  end

  on(:topic_trashed) do |topic|
    if !topic.closed && !topic.archived
      Jobs.enqueue(Jobs::DiscourseTopicVoting::VoteRelease, topic_id: topic.id, trashed: true)
    end
  end

  on(:topic_recovered) do |topic|
    if !topic.closed && !topic.archived
      Jobs.enqueue(Jobs::DiscourseTopicVoting::VoteReclaim, topic_id: topic.id)
    end
  end

  on(:post_edited) do |post, _, revisor|
    if SiteSetting.topic_voting_enabled && revisor.topic_diff.has_key?("category_id") &&
         DiscourseTopicVoting::Vote.exists?(topic_id: post.topic_id) && !post.topic.closed &&
         !post.topic.archived && !post.topic.trashed?
      new_category_id = post.reload.topic.category_id
      if Category.can_vote?(new_category_id)
        Jobs.enqueue(Jobs::DiscourseTopicVoting::VoteReclaim, topic_id: post.topic_id)
      else
        Jobs.enqueue(Jobs::DiscourseTopicVoting::VoteRelease, topic_id: post.topic_id)
      end
    end
  end

  on(:topic_merged) do |orig, dest|
    moved_votes = 0
    duplicated_votes = 0

    who_voted = orig.votes.map(&:user)
    if who_voted.present? && orig.closed
      who_voted.each do |user|
        next if user.blank?

        user_votes = user.topics_with_vote.pluck(:topic_id)
        user_archived_votes = user.topics_with_archived_vote.pluck(:topic_id)

        if user_votes.include?(orig.id) || user_archived_votes.include?(orig.id)
          if user_votes.include?(dest.id) || user_archived_votes.include?(dest.id)
            duplicated_votes += 1
            user.votes.destroy_by(topic_id: orig.id)
          else
            user
              .votes
              .find_by(topic_id: orig.id, user_id: user.id)
              .update!(topic_id: dest.id, archive: dest.closed)
            moved_votes += 1
          end
        else
          next
        end
      end
    end

    if moved_votes > 0
      orig.update_vote_count
      dest.update_vote_count

      if moderator_post = orig.ordered_posts.where(action_code: "split_topic").last
        moderator_post.raw << "\n\n#{I18n.t("topic_voting.votes_moved", count: moved_votes)}"
        if duplicated_votes > 0
          moderator_post.raw << " #{I18n.t("topic_voting.duplicated_votes", count: duplicated_votes)}"
        end
        moderator_post.save!
      end
    end
  end

  Discourse::Application.routes.prepend do
    get "c/*category_slug_path_with_id/l/votes.rss" => "list#votes_feed", :format => :rss
  end

  Discourse::Application.routes.append do
    mount DiscourseTopicVoting::Engine, at: "/voting"

    get "topics/voted-by/:username" => "list#voted_by",
        :as => "voted_by",
        :constraints => {
          username: RouteFormat.username,
        }
  end
end
