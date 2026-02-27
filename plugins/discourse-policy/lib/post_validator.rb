# frozen_string_literal: true

module DiscoursePolicy
  class PostValidator
    POLICY_REGEX = %r{\[policy[^\]]*\].*?\[/policy\]}m

    def initialize(post)
      @post = post
    end

    def validate_post
      old_raw = @post.changes[:raw]&.first
      new_raw = @post.raw

      old_policies = old_raw&.scan(POLICY_REGEX) || []
      new_policies = new_raw.scan(POLICY_REGEX)

      return true if old_policies == new_policies

      if !user_allowed?(@post.acting_user) || !user_allowed?(@post.user)
        @post.errors.add(:base, I18n.t("discourse_policy.errors.no_policy_permission"))
        return false
      end

      true
    end

    private

    def user_allowed?(user)
      user&.in_any_groups?(SiteSetting.create_policy_allowed_groups_map)
    end
  end
end
