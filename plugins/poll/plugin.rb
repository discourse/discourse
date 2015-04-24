# name: poll
# about: Official poll plugin for Discourse
# version: 0.9
# authors: Vikhyat Korrapati (vikhyat), Régis Hanol (zogstrip)
# url: https://github.com/discourse/discourse/tree/master/plugins/poll

register_asset "stylesheets/poll.scss"
register_asset "javascripts/poll_dialect.js", :server_side

PLUGIN_NAME ||= "discourse_poll".freeze

POLLS_CUSTOM_FIELD ||= "polls".freeze
VOTES_CUSTOM_FIELD ||= "polls-votes".freeze

after_initialize do

  module ::DiscoursePoll
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePoll
    end
  end

  require_dependency "application_controller"
  class DiscoursePoll::PollsController < ::ApplicationController
    requires_plugin PLUGIN_NAME

    before_filter :ensure_logged_in

    def vote
      post_id   = params.require(:post_id)
      poll_name = params.require(:poll_name)
      options   = params.require(:options)
      user_id   = current_user.id

      DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post_id}") do
        post = Post.find(post_id)

        # topic must be open
        if post.topic.try(:closed) || post.topic.try(:archived)
          return render_json_error I18n.t("poll.topic_must_be_open_to_vote")
        end

        polls = post.custom_fields[POLLS_CUSTOM_FIELD]

        return render_json_error I18n.t("poll.no_polls_associated_with_this_post") if polls.blank?

        poll = polls[poll_name]

        return render_json_error I18n.t("poll.no_poll_with_this_name", name: poll_name) if poll.blank?
        return render_json_error I18n.t("poll.poll_must_be_open_to_vote") if poll["status"] != "open"

        votes = post.custom_fields["#{VOTES_CUSTOM_FIELD}-#{user_id}"] || {}
        vote = votes[poll_name] || []

        poll["total_votes"] += 1 if vote.size == 0

        poll["options"].each do |option|
          option["votes"] -= 1 if vote.include?(option["id"])
          option["votes"] += 1 if options.include?(option["id"])
        end

        votes[poll_name] = options

        post.custom_fields[POLLS_CUSTOM_FIELD] = polls
        post.custom_fields["#{VOTES_CUSTOM_FIELD}-#{user_id}"] = votes
        post.save_custom_fields

        DiscourseBus.publish("/polls/#{post_id}", { poll: poll })

        render json: { poll: poll, vote: options }
      end
    end

    def toggle_status
      post_id   = params.require(:post_id)
      poll_name = params.require(:poll_name)
      status    = params.require(:status)

      DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post_id}") do
        post = Post.find(post_id)

        # either staff member or OP
        unless current_user.try(:staff?) || current_user.try(:id) == post.user_id
          return render_json_error I18n.t("poll.only_staff_or_op_can_toggle_status")
        end

        # topic must be open
        if post.topic.try(:closed) || post.topic.try(:archived)
          return render_json_error I18n.t("poll.topic_must_be_open_to_toggle_status")
        end

        polls = post.custom_fields[POLLS_CUSTOM_FIELD]

        return render_json_error I18n.t("poll.no_polls_associated_with_this_post") if polls.blank?
        return render_json_error I18n.t("poll.no_poll_with_this_name", name: poll_name) if polls[poll_name].blank?

        polls[poll_name]["status"] = status

        post.custom_fields[POLLS_CUSTOM_FIELD] = polls
        post.save_custom_fields

        DiscourseBus.publish("/polls/#{post_id}", { poll: polls[poll_name] })

        render json: { poll: polls[poll_name] }
      end
    end

  end

  DiscoursePoll::Engine.routes.draw do
    put "/vote" => "polls#vote"
    put "/toggle_status" => "polls#toggle_status"
  end

  Discourse::Application.routes.append do
    mount ::DiscoursePoll::Engine, at: "/polls"
  end

  Post.class_eval do
    attr_accessor :polls

    # save the polls when the post is created
    after_save do
      next if self.polls.blank? || !self.polls.is_a?(Hash)

      post = self
      polls = self.polls

      DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post.id}") do
        post.custom_fields[POLLS_CUSTOM_FIELD] = polls
        post.save_custom_fields
      end
    end
  end

  DATA_PREFIX ||= "data-poll-".freeze
  DEFAULT_POLL_NAME ||= "poll".freeze

  validate(:post, :polls) do
    # only care when raw has changed!
    return unless self.raw_changed?

    # TODO: we should fix the callback mess so that the cooked version is available
    # in the validators instead of cooking twice
    cooked = PrettyText.cook(self.raw, topic_id: self.topic_id)
    parsed = Nokogiri::HTML(cooked)

    polls = {}
    extracted_polls = []

    # extract polls
    parsed.css("div.poll").each do |p|
      poll = { "options" => [], "total_votes" => 0 }

      # extract attributes
      p.attributes.values.each do |attribute|
        if attribute.name.start_with?(DATA_PREFIX)
          poll[attribute.name[DATA_PREFIX.length..-1]] = attribute.value
        end
      end

      # extract options
      p.css("li[#{DATA_PREFIX}option-id]").each do |o|
        option_id = o.attributes[DATA_PREFIX + "option-id"].value
        poll["options"] << { "id" => option_id, "html" => o.inner_html, "votes" => 0 }
      end

      # add the poll
      extracted_polls << poll
    end

    # validate polls
    extracted_polls.each do |poll|
      # polls should have a unique name
      if polls.has_key?(poll["name"])
        poll["name"] == DEFAULT_POLL_NAME ?
          self.errors.add(:base, I18n.t("poll.multiple_polls_without_name")) :
          self.errors.add(:base, I18n.t("poll.multiple_polls_with_same_name", name: poll["name"]))
        return
      end

      # options must be unique
      if poll["options"].map { |o| o["id"] }.uniq.size != poll["options"].size
        poll["name"] == DEFAULT_POLL_NAME ?
          self.errors.add(:base, I18n.t("poll.default_poll_must_have_different_options")) :
          self.errors.add(:base, I18n.t("poll.named_poll_must_have_different_options", name: poll["name"]))
        return
      end

      # at least 2 options
      if poll["options"].size < 2
        poll["name"] == DEFAULT_POLL_NAME ?
          self.errors.add(:base, I18n.t("poll.default_poll_must_have_at_least_2_options")) :
          self.errors.add(:base, I18n.t("poll.named_poll_must_have_at_least_2_options", name: poll["name"]))
        return
      end

      # store the valid poll
      polls[poll["name"]] = poll
    end

    # are we updating a post outside the 5-minute edit window?
    if self.id.present? && self.created_at < 5.minutes.ago
      post = self
      DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post.id}") do
        # load previous polls
        previous_polls = post.custom_fields[POLLS_CUSTOM_FIELD] || {}

        # are the polls different?
        if polls.keys != previous_polls.keys ||
           polls.values.map { |p| p["options"] } != previous_polls.values.map { |p| p["options"] }

          # cannot add/remove/change/re-order polls
          if polls.keys != previous_polls.keys
            post.errors.add(:base, I18n.t("poll.cannot_change_polls_after_5_minutes"))
            return
          end

          # deal with option changes
          if User.staff.pluck(:id).include?(post.last_editor_id)
            # staff can only edit options
            polls.each_key do |poll_name|
              if polls[poll_name]["options"].size != previous_polls[poll_name]["options"].size
                post.errors.add(:base, I18n.t("poll.staff_cannot_add_or_remove_options_after_5_minutes"))
                return
              end
            end
            # merge votes
            polls.each_key do |poll_name|
              polls[poll_name]["total_votes"] = previous_polls[poll_name]["total_votes"]
              for o in 0...polls[poll_name]["options"].size
                polls[poll_name]["options"][o]["votes"] = previous_polls[poll_name]["options"][o]["votes"]
              end
            end
          else
            # OP cannot change polls after 5 minutes
            post.errors.add(:base, I18n.t("poll.cannot_change_polls_after_5_minutes"))
            return
          end
        end

        # immediately store the polls
        post.custom_fields[POLLS_CUSTOM_FIELD] = polls
        post.save_custom_fields
      end
    else
      # polls will be saved once we have a post id
      self.polls = polls
    end
  end

  Post.register_custom_field_type(POLLS_CUSTOM_FIELD, :json)
  Post.register_custom_field_type("#{VOTES_CUSTOM_FIELD}-*", :json)

  TopicView.add_post_custom_fields_whitelister do |user|
    whitelisted = [POLLS_CUSTOM_FIELD]
    whitelisted << "#{VOTES_CUSTOM_FIELD}-#{user.id}" if user
    whitelisted
  end

  add_to_serializer(:post, :polls, false) { post_custom_fields[POLLS_CUSTOM_FIELD] }
  add_to_serializer(:post, :include_polls?) { post_custom_fields.present? && post_custom_fields[POLLS_CUSTOM_FIELD].present? }

  add_to_serializer(:post, :polls_votes, false) { post_custom_fields["#{VOTES_CUSTOM_FIELD}-#{scope.user.id}"] }
  add_to_serializer(:post, :include_polls_votes?) { scope.user && post_custom_fields.present? && post_custom_fields["#{VOTES_CUSTOM_FIELD}-#{scope.user.id}"].present? }
end
