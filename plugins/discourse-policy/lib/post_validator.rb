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

      if !user_allowed?(@post.acting_user) || !user_allowed?(@post.user) ||
           !acting_user_can_manage_target_groups?(old_policies, new_policies)
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

    def acting_user_can_manage_target_groups?(old_policies, new_policies)
      old_target_group_names = old_policies.map { |policy| policy_target_group_name(policy) }

      new_policies.each_with_index.all? do |policy, index|
        target_group_name = policy_target_group_name(policy)
        next true if target_group_name.blank? || target_group_name == old_target_group_names[index]

        target_group = Group.find_by_name(target_group_name)

        !target_group || !Guardian.new(@post.user).can_edit_group?(target_group) ||
          Guardian.new(@post.acting_user).can_edit_group?(target_group)
      end
    end

    def policy_target_group_name(policy)
      Nokogiri::HTML5.fragment(policy).at_css("div.policy")["data-add-users-to-group"]
    end

    def user_allowed?(user)
      user&.in_any_groups?(SiteSetting.create_policy_allowed_groups_map)
    end
  end
end
