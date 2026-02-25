# frozen_string_literal: true

describe DiscoursePolicy::PolicyController do
  fab!(:group)
  fab!(:moderator)
  fab!(:user1, :user)
  fab!(:user2, :user)

  before do
    enable_current_plugin
    Jobs.run_immediately!
    group.add(user1)
    group.add(user2)
  end

  def raw
    <<~MD
      [policy group=#{group.name}]
      I always open **doors**!
      [/policy]
    MD
  end

  it "allows users to accept/reject policy" do
    post = create_post(raw: raw, user: moderator)

    sign_in(user1)
    put "/policy/accept.json", params: { post_id: post.id }
    expect(response.status).to eq(200)
    expect(post.reload.post_policy.accepted_by.map(&:id)).to eq([user1.id])

    sign_in(user2)
    put "/policy/accept.json", params: { post_id: post.id }
    expect(response.status).to eq(200)
    expect(post.reload.post_policy.accepted_by.map(&:id).sort).to eq([user1.id, user2.id])

    put "/policy/unaccept.json", params: { post_id: post.id }
    expect(response.status).to eq(200)
    expect(post.reload.post_policy.accepted_by.map(&:id)).to eq([user1.id])
  end

  context "when add_users_to_group is present" do
    fab!(:group2, :group)
    fab!(:post) { Fabricate(:post, user: moderator) }
    fab!(:policy666) do
      policy = Fabricate(:post_policy, post: post, add_users_to_group: group2.id)
      PostPolicyGroup.create!(post_policy_id: policy.id, group_id: group.id)
      policy
    end

    before { group2.add_owner(moderator) }

    it "adds/removes users to the group when they accept the policy" do
      sign_in(user1)
      put "/policy/accept.json", params: { post_id: post.id }

      expect(response.status).to eq(200)
      expect(post.reload.post_policy.accepted_by.map(&:id)).to eq([user1.id])
      expect(group2.users.pluck(:id)).to contain_exactly(moderator.id, user1.id)

      put "/policy/unaccept.json", params: { post_id: post.id }

      expect(response.status).to eq(200)
      expect(post.reload.post_policy.accepted_by.map(&:id)).to eq([])
      expect(group2.users.pluck(:id)).to contain_exactly(moderator.id)
    end
  end

  describe "#accepted" do
    before { sign_in(user1) }

    it "returns pages of users who accepted" do
      post = create_post(raw: raw, user: moderator)
      PolicyUser.add!(user1, post.post_policy)
      PolicyUser.add!(user2, post.post_policy)

      get "/policy/accepted.json", params: { post_id: post.id, offset: 0 }
      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].map { |x| x["id"] }).to contain_exactly(
        user1.id,
        user2.id,
      )

      get "/policy/accepted.json", params: { post_id: post.id, offset: 1 }
      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].map { |x| x["id"] }).to contain_exactly(user2.id)

      get "/policy/accepted.json", params: { post_id: post.id, offset: 2 }
      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].map { |x| x["id"] }).to contain_exactly
    end
  end

  describe "#not_accepted" do
    before { sign_in(user1) }

    it "returns pages of users who accepted" do
      post = create_post(raw: raw, user: moderator)

      get "/policy/not-accepted.json", params: { post_id: post.id, offset: 0 }
      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].map { |x| x["id"] }).to contain_exactly(
        user1.id,
        user2.id,
      )

      get "/policy/not-accepted.json", params: { post_id: post.id, offset: 1 }
      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].map { |x| x["id"] }).to contain_exactly(user2.id)

      get "/policy/not-accepted.json", params: { post_id: post.id, offset: 2 }
      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].map { |x| x["id"] }).to contain_exactly
    end
  end

  describe "post visibility checks" do
    fab!(:private_group, :group)
    fab!(:private_category) { Fabricate(:private_category, group: private_group) }
    fab!(:outsider, :user)
    fab!(:private_topic) { Fabricate(:topic, category: private_category, user: moderator) }
    fab!(:private_post) { Fabricate(:post, topic: private_topic, user: moderator) }
    fab!(:private_policy) do
      policy = Fabricate(:post_policy, post: private_post)
      PostPolicyGroup.create!(post_policy_id: policy.id, group_id: group.id)
      policy
    end

    before { group.add(outsider) }

    it "returns 404 when user cannot see the post for accept" do
      sign_in(outsider)
      put "/policy/accept.json", params: { post_id: private_post.id }
      expect(response.status).to eq(404)
    end

    it "returns 404 when user cannot see the post for unaccept" do
      sign_in(outsider)
      put "/policy/unaccept.json", params: { post_id: private_post.id }
      expect(response.status).to eq(404)
    end

    it "returns 404 when user cannot see the post for accepted" do
      sign_in(outsider)
      get "/policy/accepted.json", params: { post_id: private_post.id }
      expect(response.status).to eq(404)
    end

    it "returns 404 when user cannot see the post for not_accepted" do
      sign_in(outsider)
      get "/policy/not-accepted.json", params: { post_id: private_post.id }
      expect(response.status).to eq(404)
    end
  end

  describe "private policy restrictions" do
    fab!(:admin)

    def private_raw
      <<~MD
        [policy group=#{group.name} private=true]
        I always open **doors**!
        [/policy]
      MD
    end

    it "denies non-admin access to accepted users for a private policy" do
      post = create_post(raw: private_raw, user: moderator)
      PolicyUser.add!(user1, post.post_policy)

      sign_in(user1)
      get "/policy/accepted.json", params: { post_id: post.id, offset: 0 }
      expect(response.status).to eq(403)
    end

    it "denies non-admin access to not_accepted users for a private policy" do
      post = create_post(raw: private_raw, user: moderator)

      sign_in(user1)
      get "/policy/not-accepted.json", params: { post_id: post.id, offset: 0 }
      expect(response.status).to eq(403)
    end

    it "allows admin access to accepted users for a private policy" do
      group.add(admin)
      post = create_post(raw: private_raw, user: moderator)
      PolicyUser.add!(user1, post.post_policy)

      sign_in(admin)
      get "/policy/accepted.json", params: { post_id: post.id, offset: 0 }
      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].map { |x| x["id"] }).to include(user1.id)
    end

    it "allows admin access to not_accepted users for a private policy" do
      group.add(admin)
      post = create_post(raw: private_raw, user: moderator)

      sign_in(admin)
      get "/policy/not-accepted.json", params: { post_id: post.id, offset: 0 }
      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].map { |x| x["id"] }).to contain_exactly(
        user1.id,
        user2.id,
        admin.id,
      )
    end
  end

  describe "group member visibility restrictions" do
    fab!(:owner, :user)
    let!(:post) do
      raw = <<~MD
        [policy group=#{group.name}]
        I always open **doors**!
        [/policy]
      MD
      create_post(raw: raw, user: moderator)
    end

    before do
      group.update!(members_visibility_level: Group.visibility_levels[:owners])
      group.add_owner(owner)
    end

    it "returns 422 and error if user cannot see group members (accepted endpoint)" do
      sign_in(user2)
      get "/policy/accepted.json", params: { post_id: post.id, offset: 0 }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("discourse_policy.error.no_permission"),
      )
    end

    it "returns 422 and error if user cannot see group members (not_accepted endpoint)" do
      sign_in(user2)
      get "/policy/not-accepted.json", params: { post_id: post.id, offset: 0 }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("discourse_policy.error.no_permission"),
      )
    end

    it "allows owner to see group members" do
      PolicyUser.add!(user1, post.post_policy)

      sign_in(owner)
      get "/policy/accepted.json", params: { post_id: post.id, offset: 0 }
      expect(response.status).to eq(200)
      expect(response.parsed_body["users"].map { |x| x["id"] }).to contain_exactly(user1.id)
    end
  end

  describe "#accept" do
    fab!(:group2, :group)
    fab!(:post) { Fabricate(:post, user: moderator) }
    fab!(:post_policy) do
      policy = Fabricate(:post_policy, post: post, add_users_to_group: group2.id)
      PostPolicyGroup.create!(post_policy_id: policy.id, group_id: group.id)
      policy
    end

    it "returns 422 when the post author cannot manage the group that accepting users are added to" do
      post_policy.update!(add_users_to_group: Group::AUTO_GROUPS[:admins])
      sign_in(user1)
      put "/policy/accept.json", params: { post_id: post.id }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("discourse_policy.errors.policy_group_inaccessible"),
      )
    end
  end

  describe "#unaccept" do
    fab!(:group2, :group)
    fab!(:post) { Fabricate(:post, user: moderator) }
    fab!(:post_policy) do
      policy = Fabricate(:post_policy, post: post, add_users_to_group: group2.id)
      PostPolicyGroup.create!(post_policy_id: policy.id, group_id: group.id)
      policy
    end

    it "returns 422 when the post author cannot manage the group that accepting users are added to" do
      post_policy.update!(add_users_to_group: Group::AUTO_GROUPS[:admins])
      PolicyUser.add!(user1, post_policy)
      sign_in(user1)
      put "/policy/unaccept.json", params: { post_id: post.id }
      expect(response.status).to eq(422)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("discourse_policy.errors.policy_group_inaccessible"),
      )
    end
  end
end
