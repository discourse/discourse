module DiscoursePoll
  class PostValidator
    def initialize(post)
      @post = post
    end

    def validate_post
      min_trust_level = SiteSetting.poll_minimum_trust_level_to_create
      trusted = @post&.user&.admin ||
                @post&.user&.trust_level >= TrustLevel[min_trust_level]

      if !trusted
        message = I18n.t("poll.insufficient_trust_level_to_create",
          current: @post&.user&.trust_level,
          required: min_trust_level
        )

        @post.errors.add(:base, message)
        return false
      end

      true
    end
  end
end
