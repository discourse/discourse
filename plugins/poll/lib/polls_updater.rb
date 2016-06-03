module DiscoursePoll
  class PollsUpdater
    def self.update(post, polls)
      # load previous polls
      previous_polls = post.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD] || {}

      # extract options
      current_options = extract_option_ids(polls)
      previous_options = extract_option_ids(previous_polls)

      # are the polls different?
      if ((poll_names = polls.keys) != (previous_poll_names = previous_polls.keys)) ||
         (current_options != previous_options)

        has_votes = total_votes(previous_polls) > 0

        # outside of the 5-minute edit window?
        if post.created_at < 5.minutes.ago && has_votes
          # cannot add/remove/rename polls
          if poll_names.sort != previous_poll_names.sort
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
            PostCustomField.where(post_id: post.id, name: DiscoursePoll::VOTES_CUSTOM_FIELD).destroy_all
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
        post.custom_fields[DiscoursePoll::POLLS_CUSTOM_FIELD] = polls
        post.save_custom_fields(true)

        # publish the changes
        MessageBus.publish("/polls/#{post.topic_id}", { post_id: post.id, polls: polls })
      end
    end

    def self.extract_option_ids(polls)
      polls.values.map { |p| p["options"].map { |o| o["id"] } }.flatten.sort
    end

    def self.total_votes(polls)
      polls.map { |key, value| value["voters"].to_i }.sum
    end
  end
end
