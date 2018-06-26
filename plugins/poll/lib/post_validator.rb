module DiscoursePoll
  class PostValidator
    def initialize(post)
      @post = post
    end

    def validate_post
      min_trust_level = SiteSetting.poll_minimum_trust_level_to_create

      if @post&.user&.staff? || @post&.user&.trust_level >= TrustLevel[min_trust_level]
        true
      else
        @post.errors.add(:base, I18n.t("poll.insufficient_rights_to_create"))
        false
      end
    end
  end
end
