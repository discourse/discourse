# frozen_string_literal: true

RSpec.describe DiscoursePolicy::PostValidator do
  fab!(:policy_group, :group)
  fab!(:user)
  fab!(:post_owner, :user)
  fab!(:acting_user, :user)
  fab!(:post) { Fabricate(:post, user: post_owner) }

  let(:policy_raw) { <<~MD }
      [policy group=#{policy_group.name}]
      I agree
      [/policy]
    MD

  before do
    enable_current_plugin
    SiteSetting.create_policy_allowed_groups = "#{policy_group.id}"
  end

  describe "#validate_post" do
    it "returns true when policy blocks have not changed" do
      policy_group.add(post_owner)
      post.update!(raw: <<~MD)
        Intro

        #{policy_raw}
      MD
      post.raw = <<~MD
        New intro

        #{policy_raw}
      MD
      post.acting_user = acting_user

      result = described_class.new(post).validate_post

      expect(result).to eq(true)
    end

    it "returns true when policy blocks appear only inside blockquotes" do
      post.update!(raw: <<~MD)
        [quote="someone, post:1, topic:1"]
        #{policy_raw}
        [/quote]
      MD
      post.raw = <<~MD
        [quote="someone, post:1, topic:1"]
        #{policy_raw}
        [/quote]
        Updated quote context
      MD
      post.acting_user = acting_user

      result = described_class.new(post).validate_post

      expect(result).to eq(true)
    end

    context "when policy blocks have changed" do
      it "returns true when both users have permission to modify policy blocks" do
        policy_group.add(post_owner)
        policy_group.add(acting_user)
        post.raw = policy_raw
        post.acting_user = acting_user

        result = described_class.new(post).validate_post

        expect(result).to eq(true)
      end

      it "returns false when acting user lacks permission to modify policy blocks" do
        policy_group.add(post_owner)
        post.raw = policy_raw
        post.acting_user = acting_user

        result = described_class.new(post).validate_post

        expect(result).to eq(false)
        expect(post.errors[:base]).to include(
          I18n.t("discourse_policy.errors.no_policy_permission"),
        )
      end

      it "returns false when post owner lacks permission to modify policy blocks" do
        policy_group.add(acting_user)
        post.raw = policy_raw
        post.acting_user = acting_user

        result = described_class.new(post).validate_post

        expect(result).to eq(false)
        expect(post.errors[:base]).to include(
          I18n.t("discourse_policy.errors.no_policy_permission"),
        )
      end

      it "returns false when acting user modifies one of multiple policy blocks without permission" do
        policy_group.add(post_owner)
        second_policy_raw = <<~MD
          [policy group=#{policy_group.name}]
          I also agree
          [/policy]
        MD
        post.update!(raw: <<~MD)
          #{policy_raw}

          #{second_policy_raw}
        MD
        post.raw = <<~MD
          #{policy_raw}

          [policy group=#{policy_group.name}]
          Updated
          [/policy]
        MD
        post.acting_user = acting_user

        result = described_class.new(post).validate_post

        expect(result).to eq(false)
        expect(post.errors[:base]).to include(
          I18n.t("discourse_policy.errors.no_policy_permission"),
        )
      end

      it "returns false when acting user removes policy blocks without permission" do
        policy_group.add(post_owner)
        post.update!(raw: policy_raw)
        post.raw = "Policy removed"
        post.acting_user = acting_user

        result = described_class.new(post).validate_post

        expect(result).to eq(false)
        expect(post.errors[:base]).to include(
          I18n.t("discourse_policy.errors.no_policy_permission"),
        )
      end
    end

    context "when there is no previous raw" do
      it "returns true when author has permission to add policy blocks" do
        policy_group.add(user)
        new_post = Fabricate.build(:post, raw: policy_raw, user: user)

        result = described_class.new(new_post).validate_post

        expect(result).to eq(true)
      end

      it "returns false when author lacks permission to add policy blocks" do
        new_post = Fabricate.build(:post, raw: policy_raw, user: user)

        result = described_class.new(new_post).validate_post

        expect(result).to eq(false)
        expect(new_post.errors[:base]).to include(
          I18n.t("discourse_policy.errors.no_policy_permission"),
        )
      end

      it "returns true when raw has no policy blocks" do
        new_post = Fabricate.build(:post, raw: "No policy", user: user)

        result = described_class.new(new_post).validate_post

        expect(result).to eq(true)
      end
    end
  end
end
