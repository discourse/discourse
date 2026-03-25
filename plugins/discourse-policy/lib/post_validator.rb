# frozen_string_literal: true

module DiscoursePolicy
  class PostValidator
    def initialize(post)
      @post = post
    end

    def validate_post
      old_raw = @post.changes[:raw]&.first
      new_raw = @post.raw

      return true if !old_raw&.include?("[/policy]") && !new_raw.include?("[/policy]")

      old_policies = extract_policies(@post.cooked)
      new_policies = extract_policies(PrettyText.cook(new_raw, {}))

      return true if old_policies == new_policies

      if !user_allowed?(@post.acting_user) || !user_allowed?(@post.user)
        @post.errors.add(:base, I18n.t("discourse_policy.errors.no_policy_permission"))
        return false
      end

      true
    end

    private

    def extract_policies(cooked)
      return [] if cooked.blank?

      Nokogiri::HTML5
        .fragment(cooked)
        .css("div.policy")
        .reject { |p| p.ancestors("blockquote").any? }
        .map(&:to_html)
    end

    def user_allowed?(user)
      user&.in_any_groups?(SiteSetting.create_policy_allowed_groups_map)
    end
  end
end
