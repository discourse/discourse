# name: poll
# about: Official poll plugin for Discourse
# version: 0.9
# authors: Vikhyat Korrapati (vikhyat), Régis Hanol (zogstrip)
# url: https://github.com/discourse/discourse/tree/master/plugins/poll

enabled_site_setting :poll_enabled

register_asset "stylesheets/common/poll.scss"
register_asset "stylesheets/desktop/poll.scss", :desktop
register_asset "stylesheets/mobile/poll.scss", :mobile

register_asset "javascripts/poll_dialect.js", :server_side

PLUGIN_NAME ||= "discourse_poll".freeze

POLLS_CUSTOM_FIELD ||= "polls".freeze
VOTES_CUSTOM_FIELD ||= "polls-votes".freeze

DATA_PREFIX ||= "data-poll-".freeze
DEFAULT_POLL_NAME ||= "poll".freeze

after_initialize do

  module ::DiscoursePoll
    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace DiscoursePoll
    end
  end

  class DiscoursePoll::Poll
    class << self

      def vote(post_id, poll_name, options, user_id)
        DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post_id}") do
          post = Post.find_by(id: post_id)

          # post must not be deleted
          if post.nil? || post.trashed?
            raise StandardError.new I18n.t("poll.post_is_deleted")
          end

          # topic must not be archived
          if post.topic.try(:archived)
            raise StandardError.new I18n.t("poll.topic_must_be_open_to_vote")
          end

          polls = post.custom_fields[POLLS_CUSTOM_FIELD]

          raise StandardError.new I18n.t("poll.no_polls_associated_with_this_post") if polls.blank?

          poll = polls[poll_name]

          raise StandardError.new I18n.t("poll.no_poll_with_this_name", name: poll_name) if poll.blank?
          raise StandardError.new I18n.t("poll.poll_must_be_open_to_vote") if poll["status"] != "open"

          # remove options that aren't available in the poll
          available_options = poll["options"].map { |o| o["id"] }.to_set
          options.select! { |o| available_options.include?(o) }

          raise StandardError.new I18n.t("poll.requires_at_least_1_valid_option") if options.empty?

          poll["voters"] = poll["anonymous_voters"] || 0
          all_options = Hash.new(0)

          post.custom_fields[VOTES_CUSTOM_FIELD] ||= {}
          post.custom_fields[VOTES_CUSTOM_FIELD]["#{user_id}"] ||= {}
          post.custom_fields[VOTES_CUSTOM_FIELD]["#{user_id}"][poll_name] = options

          post.custom_fields[VOTES_CUSTOM_FIELD].each do |_, user_votes|
            next unless votes = user_votes[poll_name]
            votes.each { |option| all_options[option] += 1 }
            poll["voters"] += 1 if (available_options & votes.to_set).size > 0
          end

          poll["options"].each do |option|
            anonymous_votes = option["anonymous_votes"] || 0
            option["votes"] = all_options[option["id"]] + anonymous_votes
          end

          post.custom_fields[POLLS_CUSTOM_FIELD] = polls
          post.save_custom_fields(true)

          MessageBus.publish("/polls/#{post.topic_id}", { post_id: post_id, polls: polls })

          return [poll, options]
        end
      end

      def toggle_status(post_id, poll_name, status, user_id)
        DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post_id}") do
          post = Post.find_by(id: post_id)

          # post must not be deleted
          if post.nil? || post.trashed?
            raise StandardError.new I18n.t("poll.post_is_deleted")
          end

          # topic must not be archived
          if post.topic.try(:archived)
            raise StandardError.new I18n.t("poll.topic_must_be_open_to_toggle_status")
          end

          user = User.find_by(id: user_id)

          # either staff member or OP
          unless user_id == post.user_id || user.try(:staff?)
            raise StandardError.new I18n.t("poll.only_staff_or_op_can_toggle_status")
          end

          polls = post.custom_fields[POLLS_CUSTOM_FIELD]

          raise StandardError.new I18n.t("poll.no_polls_associated_with_this_post") if polls.blank?
          raise StandardError.new I18n.t("poll.no_poll_with_this_name", name: poll_name) if polls[poll_name].blank?

          polls[poll_name]["status"] = status

          post.save_custom_fields(true)

          MessageBus.publish("/polls/#{post.topic_id}", {post_id: post.id, polls: polls })

          polls[poll_name]
        end
      end

      def extract(raw, topic_id)
        # TODO: we should fix the callback mess so that the cooked version is available
        # in the validators instead of cooking twice
        cooked = PrettyText.cook(raw, topic_id: topic_id)
        parsed = Nokogiri::HTML(cooked)

        extracted_polls = []

        # extract polls
        parsed.css("div.poll").each do |p|
          poll = { "options" => [], "voters" => 0 }

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

        extracted_polls
      end
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

      begin
        poll, options = DiscoursePoll::Poll.vote(post_id, poll_name, options, user_id)
        render json: { poll: poll, vote: options }
      rescue StandardError => e
        render_json_error e.message
      end
    end

    def toggle_status
      post_id   = params.require(:post_id)
      poll_name = params.require(:poll_name)
      status    = params.require(:status)
      user_id   = current_user.id

      begin
        poll = DiscoursePoll::Poll.toggle_status(post_id, poll_name, status, user_id)
        render json: { poll: poll }
      rescue StandardError => e
        render_json_error e.message
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

    after_save do
      next if self.polls.blank? || !self.polls.is_a?(Hash)

      post = self
      polls = self.polls

      DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post.id}") do
        post.custom_fields[POLLS_CUSTOM_FIELD] = polls
        post.save_custom_fields(true)
      end
    end
  end

  validate(:post, :validate_polls) do
    # only care when raw has changed!
    return unless self.raw_changed?

    polls = {}

    extracted_polls = DiscoursePoll::Poll::extract(self.raw, self.topic_id)

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

      # maximum # of options
      if poll["options"].size > SiteSetting.poll_maximum_options
        poll["name"] == DEFAULT_POLL_NAME ?
          self.errors.add(:base, I18n.t("poll.default_poll_must_have_less_options", count: SiteSetting.poll_maximum_options)) :
          self.errors.add(:base, I18n.t("poll.named_poll_must_have_less_options", name: poll["name"], count: SiteSetting.poll_maximum_options))
        return
      end

      # poll with multiple choices
      if poll["type"] == "multiple"
        min = (poll["min"].presence || 1).to_i
        max = (poll["max"].presence || poll["options"].size).to_i

        if min > max || max <= 0 || max > poll["options"].size || min >= poll["options"].size
          poll["name"] == DEFAULT_POLL_NAME ?
            self.errors.add(:base, I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters")) :
            self.errors.add(:base, I18n.t("poll.named_poll_with_multiple_choices_has_invalid_parameters", name: poll["name"]))
          return
        end
      end

      # store the valid poll
      polls[poll["name"]] = poll
    end

    # are we updating a post?
    if self.id.present?
      post = self
      DistributedMutex.synchronize("#{PLUGIN_NAME}-#{post.id}") do
        # load previous polls
        previous_polls = post.custom_fields[POLLS_CUSTOM_FIELD] || {}

        # extract options
        current_options = polls.values.map { |p| p["options"].map { |o| o["id"] } }.flatten.sort
        previous_options = previous_polls.values.map { |p| p["options"].map { |o| o["id"] } }.flatten.sort

        # are the polls different?
        if polls.keys != previous_polls.keys || current_options != previous_options

          has_votes = previous_polls.keys.map { |p| previous_polls[p]["voters"].to_i }.sum > 0

          # outside of the 5-minute edit window?
          if post.created_at < 5.minutes.ago && has_votes
            # cannot add/remove/rename polls
            if polls.keys.sort != previous_polls.keys.sort
              post.errors.add(:base, I18n.t("poll.cannot_change_polls_after_5_minutes"))
              return
            end

            # deal with option changes
            if User.staff.pluck(:id).include?(post.last_editor_id)
              # staff can only edit options
              polls.each_key do |poll_name|
                if polls[poll_name]["options"].size != previous_polls[poll_name]["options"].size && previous_polls[poll_name]["voters"].to_i > 0
                  post.errors.add(:base, I18n.t("poll.staff_cannot_add_or_remove_options_after_5_minutes"))
                  return
                end
              end
            else
              # OP cannot edit poll options
              post.errors.add(:base, I18n.t("poll.op_cannot_edit_options_after_5_minutes"))
              return
            end
          end

          # try to merge votes
          polls.each_key do |poll_name|
            next unless previous_polls.has_key?(poll_name)

            # when the # of options has changed, reset all the votes
            if polls[poll_name]["options"].size != previous_polls[poll_name]["options"].size
              PostCustomField.where(post_id: post.id, name: VOTES_CUSTOM_FIELD).destroy_all
              post.clear_custom_fields
              next
            end

            polls[poll_name]["voters"] = previous_polls[poll_name]["voters"]
            polls[poll_name]["anonymous_voters"] = previous_polls[poll_name]["anonymous_voters"] if previous_polls[poll_name].has_key?("anonymous_voters")

            for o in 0...polls[poll_name]["options"].size
              current_option = polls[poll_name]["options"][o]
              previous_option = previous_polls[poll_name]["options"][o]

              current_option["votes"] = previous_option["votes"]
              current_option["anonymous_votes"] = previous_option["anonymous_votes"] if previous_option.has_key?("anonymous_votes")
            end
          end

          # immediately store the polls
          post.custom_fields[POLLS_CUSTOM_FIELD] = polls
          post.save_custom_fields(true)

          # publish the changes
          MessageBus.publish("/polls/#{post.topic_id}", { post_id: post.id, polls: polls })
        end
      end
    else
      self.polls = polls
    end

    true
  end

  Post.register_custom_field_type(POLLS_CUSTOM_FIELD, :json)
  Post.register_custom_field_type(VOTES_CUSTOM_FIELD, :json)

  TopicView.add_post_custom_fields_whitelister do |user|
    user ? [POLLS_CUSTOM_FIELD, VOTES_CUSTOM_FIELD] : [POLLS_CUSTOM_FIELD]
  end

  on(:reduce_cooked) do |fragment, post|
    if post.nil? || post.trashed?
      fragment.css(".poll, [data-poll-name]").each(&:remove)
    else
      post_url = "#{Discourse.base_url}#{post.url}"
      fragment.css(".poll, [data-poll-name]").each do |poll|
        poll.replace "<p><a href='#{post_url}'>#{I18n.t("poll.email.link_to_poll")}</a></p>"
      end
    end
  end

  # tells the front-end we have a poll for that post
  on(:post_created) do |post|
    next if post.is_first_post? || post.custom_fields[POLLS_CUSTOM_FIELD].blank?
    MessageBus.publish("/polls/#{post.topic_id}", {
                         post_id: post.id,
                         polls: post.custom_fields[POLLS_CUSTOM_FIELD]})
  end

  add_to_serializer(:post, :polls, false) { post_custom_fields[POLLS_CUSTOM_FIELD] }
  add_to_serializer(:post, :include_polls?) { post_custom_fields.present? && post_custom_fields[POLLS_CUSTOM_FIELD].present? }

  add_to_serializer(:post, :polls_votes, false) { post_custom_fields[VOTES_CUSTOM_FIELD]["#{scope.user.id}"] }
  add_to_serializer(:post, :include_polls_votes?) do
    return unless scope.user
    return unless post_custom_fields.present?
    return unless post_custom_fields[VOTES_CUSTOM_FIELD].present?
    post_custom_fields[VOTES_CUSTOM_FIELD].has_key?("#{scope.user.id}")
  end
end
