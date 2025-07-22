# frozen_string_literal: true

require "rails_helper"

describe PostSerializer do
  fab!(:group)
  fab!(:admin)
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }

  before do
    enable_current_plugin
    Jobs.run_immediately!

    group.add(admin)
    group.add(user1)
    group.add(user2)
  end

  it "includes users in the serializer" do
    raw = <<~MD
     [policy group=#{group.name}]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))
    post.reload

    json = PostSerializer.new(post, scope: Guardian.new).as_json
    accepted = json[:post][:policy_accepted_by]

    expect(accepted.length).to eq(0)

    not_accepted = json[:post][:policy_not_accepted_by]

    expect(not_accepted.map { |u| u[:id] }).to contain_exactly(admin.id, user1.id, user2.id)

    PolicyUser.add!(user1, post.post_policy)

    json = PostSerializer.new(post, scope: Guardian.new).as_json

    not_accepted = json[:post][:policy_not_accepted_by]
    accepted = json[:post][:policy_accepted_by]

    expect(not_accepted.map { |u| u[:id] }).to contain_exactly(admin.id, user2.id)
    expect(accepted.map { |u| u[:id] }).to contain_exactly(user1.id)
  end

  it "works if group not found" do
    raw = <<~MD
     [policy group=#{group.name}]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))
    post.reload

    group.destroy!

    json = PostSerializer.new(post, scope: Guardian.new).as_json
    puts json.inspect

    not_accepted = json[:post][:policy_not_accepted_by]

    expect(not_accepted).to eq(nil)
  end

  it "excludes inactive users" do
    user1.active = false
    user1.save!

    raw = <<~MD
     [policy group=#{group.name} private=true]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))
    post.reload

    PolicyUser.add!(user1, post.post_policy)

    json = PostSerializer.new(post, scope: admin.guardian).as_json
    expect(json[:post][:policy_accepted_by]).to be_empty
  end

  it "excludes suspended users" do
    user1.suspended_till = 1.year.from_now
    user1.save!

    raw = <<~MD
     [policy group=#{group.name} private=true]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))
    post.reload

    PolicyUser.add!(user1, post.post_policy)

    json = PostSerializer.new(post, scope: admin.guardian).as_json
    expect(json[:post][:policy_accepted_by]).to be_empty
  end

  it "does not include users if private" do
    raw = <<~MD
     [policy group=#{group.name} private=true]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))
    post.reload

    PolicyUser.add!(user1, post.post_policy)

    json = PostSerializer.new(post, scope: Guardian.new).as_json
    expect(json[:post][:policy_not_accepted_by]).to eq(nil)
    expect(json[:post][:policy_accepted_by]).to eq(nil)
    expect(json[:post][:policy_stats]).to eq(nil)

    json = PostSerializer.new(post, scope: admin.guardian).as_json
    expect(json[:post][:policy_not_accepted_by].map { |u| u[:id] }).to contain_exactly(
      admin.id,
      user2.id,
    )
    expect(json[:post][:policy_accepted_by].map { |u| u[:id] }).to contain_exactly(user1.id)
  end

  it "does not include users if group members are not visible to the user" do
    group.update!(members_visibility_level: Group.visibility_levels[:owners])
    owner = Fabricate(:user)
    group.add_owner(owner)

    raw = <<~MD
     [policy group=#{group.name}]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))
    post.reload

    PolicyUser.add!(user1, post.post_policy)

    # A non-owner, non-admin user should not see the user lists
    json = PostSerializer.new(post, scope: Guardian.new(user2)).as_json
    expect(json[:post][:policy_not_accepted_by]).to eq(nil)
    expect(json[:post][:policy_accepted_by]).to eq(nil)

    # The owner should see the user lists
    json = PostSerializer.new(post, scope: Guardian.new(owner)).as_json
    expect(json[:post][:policy_not_accepted_by].map { |u| u[:id] }).to include(admin.id, user2.id)
    expect(json[:post][:policy_accepted_by].map { |u| u[:id] }).to include(user1.id)
  end

  describe "policy_easy_revoke" do
    it "lets user accept and revoke post at the same time if enabled" do
      raw = <<~MD
       [policy group=#{group.name}]
       I always open **doors**!
       [/policy]
      MD

      post = create_post(raw: raw, user: Fabricate(:admin))
      post.reload

      json = PostSerializer.new(post, scope: admin.guardian).as_json
      expect(json[:post][:policy_can_accept]).to eq(true)
      expect(json[:post][:policy_can_revoke]).to eq(false)

      SiteSetting.policy_easy_revoke = true

      json = PostSerializer.new(post, scope: admin.guardian).as_json
      expect(json[:post][:policy_can_accept]).to eq(true)
      expect(json[:post][:policy_can_revoke]).to eq(true)
    end
  end
end
