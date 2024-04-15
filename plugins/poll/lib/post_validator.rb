# frozen_string_literal: true

module DiscoursePoll
  class PostValidator
    def initialize(post)
      @post = post
    end

    def validate_post
      if (
           @post.acting_user &&
             (
               @post.acting_user.staff? ||
                 @post.acting_user.in_any_groups?(SiteSetting.poll_create_allowed_groups_map)
             )
         ) || @post.topic&.pm_with_non_human_user?
        true
      else
        @post.errors.add(:base, I18n.t("poll.insufficient_rights_to_create"))
        false
      end
    end
  end
end
