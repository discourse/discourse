module DiscoursePoll
  class PollsUpdater
    VALID_POLLS_CONFIGS = %w{type min max public close}.map(&:freeze)

    def self.update(post, polls)
      # load previous polls
      previous_polls = post.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD] || {}

      # extract options
      current_option_ids = extract_option_ids(polls)
      previous_option_ids = extract_option_ids(previous_polls)

      # are the polls different?
      if polls_updated?(polls, previous_polls) || (current_option_ids != previous_option_ids)
        has_votes = total_votes(previous_polls) > 0

        # outside of the edit window?
        poll_edit_window_mins = SiteSetting.poll_edit_window_mins

        if post.created_at < poll_edit_window_mins.minutes.ago && has_votes
          # deal with option changes
          if User.staff.where(id: post.last_editor_id).exists?
            # staff can edit options
            polls.each_key do |poll_name|
              if polls.dig(poll_name, "options")&.size != previous_polls.dig(poll_name, "options")&.size && previous_polls.dig(poll_name, "voters").to_i > 0
                post.errors.add(:base, I18n.t("poll.edit_window_expired.staff_cannot_add_or_remove_options", minutes: poll_edit_window_mins))
                return
              end
            end
          else
            # OP cannot edit poll options
            post.errors.add(:base, I18n.t("poll.edit_window_expired.op_cannot_edit_options", minutes: poll_edit_window_mins))
            return
          end
        end

        # try to merge votes
        polls.each_key do |poll_name|
          next unless previous_polls.has_key?(poll_name)
          return if has_votes && private_to_public_poll?(post, previous_polls, polls, poll_name)

          # when the # of options has changed, reset all the votes
          if polls[poll_name]["options"].size != previous_polls[poll_name]["options"].size
            PostCustomField.where(post_id: post.id, name: DiscoursePoll::VOTES_CUSTOM_FIELD).destroy_all
            post.clear_custom_fields
            next
          end

          polls[poll_name]["voters"] = previous_polls[poll_name]["voters"]

          if previous_polls[poll_name].has_key?("anonymous_voters")
            polls[poll_name]["anonymous_voters"] = previous_polls[poll_name]["anonymous_voters"]
          end

          previous_options = previous_polls[poll_name]["options"]
          public_poll = polls[poll_name]["public"] == "true"

          polls[poll_name]["options"].each_with_index do |option, index|
            previous_option = previous_options[index]
            option["votes"] = previous_option["votes"]

            if previous_option["id"] != option["id"]
              if votes_fields = post.custom_fields[DiscoursePoll::VOTES_CUSTOM_FIELD]
                votes_fields.each do |key, value|
                  next unless value[poll_name]
                  index = value[poll_name].index(previous_option["id"])
                  votes_fields[key][poll_name][index] = option["id"] if index
                end
              end
            end

            if previous_option.has_key?("anonymous_votes")
              option["anonymous_votes"] = previous_option["anonymous_votes"]
            end

            if public_poll && previous_option.has_key?("voter_ids")
              option["voter_ids"] = previous_option["voter_ids"]
            end
          end
        end

        # immediately store the polls
        post.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD] = polls
        post.save_custom_fields(true)

        # re-schedule jobs
        DiscoursePoll::Poll.schedule_jobs(post)

        # publish the changes
        MessageBus.publish("/polls/#{post.topic_id}", post_id: post.id, polls: polls)
      end
    end

    def self.polls_updated?(current_polls, previous_polls)
      return true if (current_polls.keys.sort != previous_polls.keys.sort)

      current_polls.each_key do |poll_name|
        if !previous_polls[poll_name] || (current_polls[poll_name].values_at(*VALID_POLLS_CONFIGS) != previous_polls[poll_name].values_at(*VALID_POLLS_CONFIGS))
          return true
        end
      end

      false
    end

    def self.extract_option_ids(polls)
      polls.values.map { |p| p["options"].map { |o| o["id"] } }.flatten.sort
    end

    def self.total_votes(polls)
      polls.map { |key, value| value["voters"].to_i }.sum
    end

    private

    def self.private_to_public_poll?(post, previous_polls, current_polls, poll_name)
      previous_poll = previous_polls[poll_name]
      current_poll  = current_polls[poll_name]

      if previous_poll["public"].nil? && current_poll["public"] == "true"
        error = poll_name == DiscoursePoll::DEFAULT_POLL_NAME ?
          I18n.t("poll.default_cannot_be_made_public") :
          I18n.t("poll.named_cannot_be_made_public", name: poll_name)

        post.errors.add(:base, error)
        return true
      end

      false
    end
  end
end
