# frozen_string_literal: true

module DiscoursePoll
  class PollsValidator

    MAX_VALUE = 2_147_483_647

    def initialize(post)
      @post = post
    end

    def validate_polls
      polls = {}

      DiscoursePoll::Poll::extract(@post.raw, @post.topic_id, @post.user_id).each do |poll|
        return false unless valid_arguments?(poll)
        return false unless valid_numbers?(poll)
        return false unless unique_poll_name?(polls, poll)
        return false unless unique_options?(poll)
        return false unless any_blank_options?(poll)
        return false unless at_least_one_option?(poll)
        return false unless valid_number_of_options?(poll)
        return false unless valid_multiple_choice_settings?(poll)
        polls[poll["name"]] = poll
      end

      polls
    end

    private

    def valid_arguments?(poll)
      valid = true

      if poll["type"].present? && !::Poll.types.has_key?(poll["type"])
        @post.errors.add(:base, I18n.t("poll.invalid_argument", argument: "type", value: poll["type"]))
        valid = false
      end

      if poll["status"].present? && !::Poll.statuses.has_key?(poll["status"])
        @post.errors.add(:base, I18n.t("poll.invalid_argument", argument: "status", value: poll["status"]))
        valid = false
      end

      if poll["results"].present? && !::Poll.results.has_key?(poll["results"])
        @post.errors.add(:base, I18n.t("poll.invalid_argument", argument: "results", value: poll["results"]))
        valid = false
      end

      valid
    end

    def unique_poll_name?(polls, poll)
      if polls.has_key?(poll["name"])
        if poll["name"] == ::DiscoursePoll::DEFAULT_POLL_NAME
          @post.errors.add(:base, I18n.t("poll.multiple_polls_without_name"))
        else
          @post.errors.add(:base, I18n.t("poll.multiple_polls_with_same_name", name: poll["name"]))
        end

        return false
      end

      true
    end

    def unique_options?(poll)
      if poll["options"].map { |o| o["id"] }.uniq.size != poll["options"].size
        if poll["name"] == ::DiscoursePoll::DEFAULT_POLL_NAME
          @post.errors.add(:base, I18n.t("poll.default_poll_must_have_different_options"))
        else
          @post.errors.add(:base, I18n.t("poll.named_poll_must_have_different_options", name: poll["name"]))
        end

        return false
      end

      true
    end

    def any_blank_options?(poll)
      if poll["options"].any? { |o| o["html"].blank? }
        if poll["name"] == ::DiscoursePoll::DEFAULT_POLL_NAME
          @post.errors.add(:base, I18n.t("poll.default_poll_must_not_have_any_empty_options"))
        else
          @post.errors.add(:base, I18n.t("poll.named_poll_must_not_have_any_empty_options", name: poll["name"]))
        end

        return false
      end

      true
    end

    def at_least_one_option?(poll)
      if poll["options"].size < 1
        if poll["name"] == ::DiscoursePoll::DEFAULT_POLL_NAME
          @post.errors.add(:base, I18n.t("poll.default_poll_must_have_at_least_1_option"))
        else
          @post.errors.add(:base, I18n.t("poll.named_poll_must_have_at_least_1_option", name: poll["name"]))
        end

        return false
      end

      true
    end

    def valid_number_of_options?(poll)
      if poll["options"].size > SiteSetting.poll_maximum_options
        if poll["name"] == ::DiscoursePoll::DEFAULT_POLL_NAME
          @post.errors.add(:base, I18n.t("poll.default_poll_must_have_less_options", count: SiteSetting.poll_maximum_options))
        else
          @post.errors.add(:base, I18n.t("poll.named_poll_must_have_less_options", name: poll["name"], count: SiteSetting.poll_maximum_options))
        end

        return false
      end

      true
    end

    def valid_multiple_choice_settings?(poll)
      if poll["type"] == "multiple"
        options = poll["options"].size
        min = (poll["min"].presence || 1).to_i
        max = (poll["max"].presence || options).to_i

        if min > max || min <= 0 || max <= 0 || max > options || min >= options
          if poll["name"] == ::DiscoursePoll::DEFAULT_POLL_NAME
            @post.errors.add(:base, I18n.t("poll.default_poll_with_multiple_choices_has_invalid_parameters"))
          else
            @post.errors.add(:base, I18n.t("poll.named_poll_with_multiple_choices_has_invalid_parameters", name: poll["name"]))
          end

          return false
        end
      end

      true
    end

    def valid_numbers?(poll)
      return true if poll["type"] != "number"

      valid = true

      min = poll["min"].to_i
      max = (poll["max"].presence || MAX_VALUE).to_i
      step = (poll["step"].presence || 1).to_i

      if min < 0
        @post.errors.add(:base, "Min #{I18n.t("errors.messages.greater_than", count: 0)}")
        valid = false
      elsif min > MAX_VALUE
        @post.errors.add(:base, "Min #{I18n.t("errors.messages.less_than", count: MAX_VALUE)}")
        valid = false
      end

      if max < min
        @post.errors.add(:base, "Max #{I18n.t("errors.messages.greater_than", count: "min")}")
        valid = false
      elsif max > MAX_VALUE
        @post.errors.add(:base, "Max #{I18n.t("errors.messages.less_than", count: MAX_VALUE)}")
        valid = false
      end

      if step <= 0
        @post.errors.add(:base, "Step #{I18n.t("errors.messages.greater_than", count: 0)}")
        valid = false
      elsif ((max - min + 1) / step) < 2
        if poll["name"] == ::DiscoursePoll::DEFAULT_POLL_NAME
          @post.errors.add(:base, I18n.t("poll.default_poll_must_have_at_least_1_option"))
        else
          @post.errors.add(:base, I18n.t("poll.named_poll_must_have_at_least_1_option", name: poll["name"]))
        end
        valid = false
      end

      valid
    end
  end
end
