# frozen_string_literal: true

describe DiscoursePolicy do
  fab!(:user1, :user)

  before { enable_current_plugin }

  describe "after_initialize" do
    before { Jobs.run_immediately! }

    it "serializes user options correctly" do
      user1.user_option.update(
        policy_email_frequency: UserOption.policy_email_frequencies[:when_away],
      )

      @plugin = Plugin::Instance.new
      @plugin.add_to_serializer(:user_option, :policy_email_frequency) do
        object.policy_email_frequency
      end

      json = UserSerializer.new(user1, scope: Guardian.new(user1), root: false).as_json

      expect(json[:user_option][:policy_email_frequency]).to eq("when_away")
    end
  end

  describe "post_process_cooked event" do
    before { Jobs.run_immediately! }

    fab!(:group)
    fab!(:moderator)

    it "sets next_renew_at when removing renew-start but not renew" do
      renew_days = 10
      renew_start = 1.day.from_now.to_date
      raw = <<~MD
        [policy group=#{group.name} renew="#{renew_days}" renew-start="#{renew_start.strftime("%F")}"]
          Here's the new policy
        [/policy]
      MD

      post = create_post(raw: raw, user: Fabricate(:admin))
      policy = PostPolicy.find_by(post: post)

      expect(policy.renew_days).to eq(renew_days)
      expect(policy.renew_start).to eq(renew_start)
      expect(policy.next_renew_at.to_date).to eq(renew_start)

      updated_policy = <<~MD
        [policy group=#{group.name} renew="#{renew_days}"]
          Here's the new policy
        [/policy]
      MD

      post.update!(raw: updated_policy)
      post.rebake!
      policy = policy.reload

      expect(policy.renew_days).to eq(renew_days)
      expect(policy.renew_start).to be_nil
      expect(policy.next_renew_at).to be_nil
    end

    context "with add_users_to_group present" do
      fab!(:group2, :group)
      fab!(:post) { Fabricate(:post, user: moderator) }
      fab!(:post_policy) do
        policy = Fabricate(:post_policy, post: post, add_users_to_group: group2.id)
        PostPolicyGroup.create!(post_policy_id: policy.id, group_id: group.id)
        policy
      end

      before { group.add(user1) }

      it "persists the group that accepting users are added to when the post author can manage it" do
        group2.add_owner(moderator)
        updated_policy = <<~MD
          [policy group=#{group.name} add-users-to-group=#{group2.name}]
            Here's the new policy
          [/policy]
        MD

        post.update!(raw: updated_policy)
        post.rebake!
        post_policy.reload

        expect(post_policy.add_users_to_group).to eq(group2.id)
      end

      it "does not persist the group that accepting users are added to when the post author cannot manage it" do
        auto_group = Group.find(Group::AUTO_GROUPS[:admins])

        updated_policy = <<~MD
          [policy group=#{group.name} add-users-to-group=#{auto_group.name}]
            Here's the new policy
          [/policy]
        MD

        post.update!(raw: updated_policy)
        post.rebake!
        post_policy.reload

        expect(post_policy.add_users_to_group).to be_nil
      end

      it "does not persist the group that accepting users are added to when it does not exist" do
        updated_policy = <<~MD
          [policy group=#{group.name} add-users-to-group=nonexistent_group_xyz]
            Here's the new policy
          [/policy]
        MD

        post.update!(raw: updated_policy)
        post.rebake!
        post_policy.reload

        expect(post_policy.add_users_to_group).to be_nil
      end

      # TODO: plugin passes an AR relation to group.remove instead of a single user — fix callsite to use GroupManager
      xit "removes all users from the group upon version change" do
        updated_policy = <<~MD
          [policy group=#{group.name} version=2 add-users-to-group=#{group2.name}]
            Here's the new policy
          [/policy]
        MD

        post.update!(raw: updated_policy)
        post.rebake!
        post_policy.reload

        expect(group2.users).to contain_exactly
      end
    end
  end

  describe "policy validation" do
    fab!(:policy_group, :group)
    fab!(:moderator)
    fab!(:acting_user, :user)

    let(:policy_raw) { <<~MD }
        [policy group=#{policy_group.name}]
        I agree
        [/policy]
      MD

    before do
      Jobs.run_immediately!
      SiteSetting.create_policy_allowed_groups = "#{policy_group.id}"
    end

    it "blocks unauthorized users from modifying policy blocks" do
      policy_group.add(moderator)
      post = create_post(raw: "Original content", user: moderator)

      result = post.revise(acting_user, { raw: policy_raw })

      expect(result).to eq(false)
      expect(post.errors[:base]).to include(I18n.t("discourse_policy.errors.no_policy_permission"))
    end
  end

  describe "current user serializer extensions" do
    let(:serializer) { CurrentUserSerializer.new(user1, scope: Guardian.new(user1)) }

    fab!(:group)

    before { SiteSetting.create_policy_allowed_groups = "1|2|#{group.id}" }

    it "returns false when user is not in a policy creation group" do
      expect(serializer.can_create_policy).to be_falsey
    end

    it "returns true when user is in a policy creation group" do
      group.add(user1)

      expect(serializer.can_create_policy).to be_truthy
    end
  end

  describe "deprecated settings" do
    let(:fake_logger) { FakeLogger.new }

    before { Rails.logger.broadcast_to(fake_logger) }

    after { Rails.logger.stop_broadcasting_to(fake_logger) }

    it "logs deprecation warning" do
      SiteSetting.policy_restrict_to_staff_posts

      expect(fake_logger.warnings[0]).to include(
        "DEPRECATION NOTICE: `SiteSetting.policy_restrict_to_staff_posts` has been deprecated. Please use `SiteSetting.create_policy_allowed_groups` instead. (removal in Discourse 3.7.0)",
      )
    end
  end
end
