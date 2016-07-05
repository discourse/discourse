module DiscoursePoll
  class PollsValidator
    def initialize(post)
      @post = post
    end

    def validate_polls
      polls = {}

      extracted_polls = DiscoursePoll::Poll::extract(@post.raw, @post.topic_id)

      extracted_polls.each do |poll|
        # polls should have a unique name
        return false unless unique_poll_id?(polls, poll)

        # options must be unique
        return false unless unique_options?(poll)

        # at least 2 options
        return false unless at_least_two_options?(poll)

        # maximum # of options
        return false unless valid_number_of_options?(poll)

        # poll with multiple choices
        return false unless valid_multiple_choice_settings?(poll)

        # store the valid poll
        polls[poll["id"]] = poll
      end

      polls
    end

    private

    def default_poll?(poll)
      [::DiscoursePoll::DEFAULT_POLL_NAME, "1"].include?(poll["id"])
    end

    def unique_poll_id?(polls, poll)
      if polls.has_key?(poll["id"])
        if default_poll?(poll)
          @post.errors.add(:base, I18n.t("poll.multiple_polls_without_id"))
        else
          @post.errors.add(:base, I18n.t("poll.multiple_polls_with_same_id", id: poll["id"]))
        end

        return false
      end

      true
    end

    def unique_options?(poll)
      if poll["options"].map { |o| o["id"] }.uniq.size != poll["options"].size
        if default_poll?(poll)
          @post.errors.add(:base, I18n.t("poll.default_poll_must_have_different_options"))
        else
          @post.errors.add(:base, I18n.t("poll.multiple_polls_must_have_different_options", id: poll["id"]))
        end

        return false
      end

      true
    end

    def at_least_two_options?(poll)
      if poll["options"].size < 2
        if default_poll?(poll)
          @post.errors.add(:base, I18n.t("poll.default_poll_must_have_at_least_2_options"))
        else
          @post.errors.add(:base, I18n.t("poll.multiple_polls_must_have_at_least_2_options", id: poll["id"]))
        end

        return false
      end

      true
    end

    def valid_number_of_options?(poll)
      if poll["options"].size > SiteSetting.poll_maximum_options
        if default_poll?(poll)
          @post.errors.add(:base, I18n.t("poll.default_poll_must_have_less_options", count: SiteSetting.poll_maximum_options))
        else
          @post.errors.add(:base, I18n.t("poll.multiple_polls_must_have_less_options", id: poll["id"], count: SiteSetting.poll_maximum_options))
        end

        return false
      end

      true
    end

    def valid_multiple_choice_settings?(poll)
      if poll["type"] == "multiple"
        num_of_options = poll["options"].size
        min = (poll["min"].presence || 1).to_i
        max = (poll["max"].presence || num_of_options).to_i

        if min > max || min <= 0 || max <= 0 || max > num_of_options || min >= num_of_options
          if default_poll?(poll)
            @post.errors.add(:base, I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters"))
          else
            @post.errors.add(:base, I18n.t("poll.multiple_polls_with_multiple_choices_has_invalid_parameters", id: poll["id"]))
          end

          return false
        end
      end

      true
    end
  end
end
