# frozen_string_literal: true

require "rails_helper"

describe PolicyUser do
  before do
    enable_current_plugin
    Jobs.run_immediately!
  end

  fab!(:user)

  fab!(:group) do
    group = Fabricate(:group)
    group.add(user)
    group
  end

  it "allows to accept and revoke policy" do
    raw = <<~MD
     [policy group=#{group.name} renew=400]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))

    described_class.add!(user, post.post_policy)
    expect(post.post_policy.accepted_by).to eq([user])

    described_class.remove!(user, post.post_policy)
    expect(post.post_policy.accepted_by).to eq([])
  end
end
