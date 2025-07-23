# frozen_string_literal: true

require "rails_helper"

describe Jobs::UserEmail do
  fab!(:user1) { Fabricate(:user) }

  fab!(:group1) do
    group = Fabricate(:group)
    group.add(user1)
    group
  end

  before { enable_current_plugin }

  it "sends a policy alert email to users who have opted in" do
    raw = <<~MD
      [policy group=#{group1.name} reminder=weekly]
      I always open **doors**!
      [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))

    Jobs::UserEmail.new.execute(type: "policy_email", user_id: user1.id, post_id: post.id)

    email = ActionMailer::Base.deliveries.first

    expect(email.to).to contain_exactly(user1.email)
    expect(email.subject).to eq I18n.t(
         "user_notifications.policy_email.subject",
         topic_title: post.topic.title,
       )
    expect(email.subject).to include(post.topic.title)
    expect(email.parts[0].body.to_s).to include(post.url)
  end
end
