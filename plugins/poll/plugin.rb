# frozen_string_literal: true

# name: poll
# about: Official poll plugin for Discourse
# version: 1.0
# authors: Vikhyat Korrapati (vikhyat), Régis Hanol (zogstrip)
# url: https://github.com/discourse/discourse/tree/main/plugins/poll

register_asset "stylesheets/common/poll.scss"
register_asset "stylesheets/common/poll-ui-builder.scss"
register_asset "stylesheets/desktop/poll-ui-builder.scss", :desktop
register_asset "stylesheets/common/poll-breakdown.scss"

register_svg_icon "far-square-check"

enabled_site_setting :poll_enabled
hide_plugin

after_initialize do
  module ::DiscoursePoll
    PLUGIN_NAME = "poll"
    DATA_PREFIX = "data-poll-"
    HAS_POLLS = "has_polls"
    DEFAULT_POLL_NAME = "poll"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePoll
    end

    class Error < StandardError
    end
  end

  require_relative "app/controllers/polls_controller"
  require_relative "app/models/poll_option"
  require_relative "app/models/poll_vote"
  require_relative "app/models/poll"
  require_relative "app/serializers/poll_option_serializer"
  require_relative "app/serializers/poll_serializer"
  require_relative "jobs/regular/close_poll"
  require_relative "lib/poll"
  require_relative "lib/ranked_choice"
  require_relative "lib/polls_updater"
  require_relative "lib/polls_validator"
  require_relative "lib/post_validator"
  require_relative "lib/post_extension"
  require_relative "lib/user_extension"

  DiscoursePoll::Engine.routes.draw do
    put "/vote" => "polls#vote"
    delete "/vote" => "polls#remove_vote"
    put "/toggle_status" => "polls#toggle_status"
    get "/voters" => "polls#voters"
    get "/grouped_poll_results" => "polls#grouped_poll_results"
  end

  Discourse::Application.routes.append { mount ::DiscoursePoll::Engine, at: "/polls" }

  allow_new_queued_post_payload_attribute("is_poll")
  register_post_custom_field_type(DiscoursePoll::HAS_POLLS, :boolean)
  topic_view_post_custom_fields_allowlister { [DiscoursePoll::HAS_POLLS] }

  reloadable_patch do
    Post.prepend(DiscoursePoll::PostExtension)
    User.prepend(DiscoursePoll::UserExtension)
  end

  validate(:post, :validate_polls) do |force = nil|
    return unless self.raw_changed? || force

    validator = DiscoursePoll::PollsValidator.new(self)
    return unless (polls = validator.validate_polls)
    return if polls.blank? && self.id.blank?

    if polls.present?
      validator = DiscoursePoll::PostValidator.new(self)
      return unless validator.validate_post
    end

    # are we updating a post?
    if self.id.present?
      return if polls.blank? && ::Poll.where(post: self).empty?

      DiscoursePoll::PollsUpdater.update(self, polls)
    else
      self.extracted_polls = polls
    end

    true
  end

  NewPostManager.add_handler(1) do |manager|
    post = Post.new(raw: manager.args[:raw])

    if !DiscoursePoll::PollsValidator.new(post).validate_polls
      result = NewPostResult.new(:poll, false)

      post.errors.full_messages.each { |message| result.add_error(message) }

      result
    else
      manager.args["is_poll"] = true
      nil
    end
  end

  on(:approved_post) do |queued_post, created_post|
    created_post.validate_polls(true) if queued_post.payload["is_poll"]
  end

  on(:reduce_cooked) do |fragment, post|
    if post.nil? || post.trashed?
      fragment.css(".poll, [data-poll-name]").each(&:remove)
    else
      post_url = post.full_url
      fragment
        .css(".poll, [data-poll-name]")
        .each do |poll|
          poll.replace "<p><a href='#{post_url}'>#{I18n.t("poll.email.link_to_poll")}</a></p>"
        end
    end
  end

  on(:reduce_excerpt) do |doc, options|
    post = options[:post]

    replacement =
      (
        if post&.url.present?
          "<a href='#{UrlHelper.normalized_encode(post.url)}'>#{I18n.t("poll.poll")}</a>"
        else
          I18n.t("poll.poll")
        end
      )

    doc.css("div.poll").each { |poll| poll.replace(replacement) }
  end

  on(:post_created) do |post, _opts, user|
    guardian = Guardian.new(user)
    DiscoursePoll::Poll.schedule_jobs(post)

    next if post.is_first_post?
    next if post.custom_fields[DiscoursePoll::HAS_POLLS].blank?

    polls =
      ActiveModel::ArraySerializer.new(
        post.polls,
        each_serializer: PollSerializer,
        root: false,
        scope: guardian,
      ).as_json
    post.publish_message!("/polls/#{post.topic_id}", post_id: post.id, polls: polls)
  end

  on(:merging_users) do |source_user, target_user|
    DB.exec(<<-SQL, source_user_id: source_user.id, target_user_id: target_user.id)
      DELETE FROM poll_votes
      WHERE user_id = :source_user_id
      AND EXISTS (
        SELECT 1
        FROM poll_votes
        WHERE user_id = :target_user_id
          AND poll_votes.poll_id = poll_votes.poll_id
      );

      UPDATE poll_votes
      SET user_id = :target_user_id
      WHERE user_id = :source_user_id;
    SQL
  end

  add_to_class(:topic_view, :polls) do
    @polls ||=
      begin
        polls = {}

        post_with_polls =
          @post_custom_fields.each_with_object([]) do |fields, obj|
            obj << fields[0] if fields[1][DiscoursePoll::HAS_POLLS]
          end

        if post_with_polls.present?
          all_polls = Poll.includes(:poll_options).where(post_id: post_with_polls)
          Poll.preload!(all_polls, user_id: @user&.id)
          DiscoursePoll::Poll.preload_serialized_voters!(all_polls)
          all_polls.each do |p|
            polls[p.post_id] ||= []
            polls[p.post_id] << p
          end
        end

        polls
      end
  end

  add_to_serializer(:current_user, :can_create_poll) do
    scope.user&.staff? || scope.user&.in_any_groups?(SiteSetting.poll_create_allowed_groups_map)
  end

  add_to_class(PostSerializer, :preloaded_polls) do
    @preloaded_polls ||=
      if @topic_view.present?
        @topic_view.polls[object.id]
      else
        Poll.includes(:poll_options).where(post: object)
      end
  end

  add_to_serializer(:post, :polls, include_condition: -> { preloaded_polls.present? }) do
    preloaded_polls.map { |p| PollSerializer.new(p, root: false, scope: self.scope) }
  end

  add_to_serializer(
    :post,
    :polls_votes,
    include_condition: -> do
      scope.user&.id.present? && preloaded_polls.present? &&
        preloaded_polls.any? { |p| p.has_voted?(scope.user) }
    end,
  ) do
    preloaded_polls
      .map do |poll|
        if poll.ranked_choice?
          user_poll_votes =
            poll
              .poll_votes
              .where(user_id: scope.user.id)
              .joins(:poll_option)
              .pluck("poll_options.digest", "poll_votes.rank")
              .map { |digest, rank| { digest: digest, rank: rank } }
        else
          user_poll_votes =
            poll
              .poll_votes
              .where(user_id: scope.user.id)
              .joins(:poll_option)
              .pluck("poll_options.digest")
        end
        [poll.name, user_poll_votes]
      end
      .to_h
  end

  register_search_advanced_filter(/in:polls/) do |posts, match|
    if SiteSetting.poll_enabled
      posts.joins(:polls)
    else
      posts
    end
  end
end
