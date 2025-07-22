# frozen_string_literal: true

require "rails_helper"

describe PrettyText do
  before do
    enable_current_plugin
    Jobs.run_immediately!
  end

  it "can properly decorate policies (legacy)" do
    raw = <<~MD
      [policy group=team renew-start="2010-01-01" reminder=weekly accept=banana revoke=apple]
      I always open **doors**!
      [/policy]
    MD

    cooked = (<<~HTML).strip
      <div class="policy" data-accept="banana" data-group="team" data-reminder="weekly" data-renew-start="2010-01-01" data-revoke="apple" data-version="1">
      <p>I always open <strong>doors</strong>!</p>
      </div>
    HTML

    expect(PrettyText.cook(raw)).to match_html(cooked)
  end

  it "can properly decorate policies" do
    raw = <<~MD
      [policy groups=team,staff renew-start="2010-01-01" reminder=weekly accept=banana revoke=apple]
      I always open **doors**!
      [/policy]
    MD

    cooked = (<<~HTML).strip
      <div class="policy" data-accept="banana" data-groups="team,staff" data-reminder="weekly" data-renew-start="2010-01-01" data-revoke="apple" data-version="1">
      <p>I always open <strong>doors</strong>!</p>
      </div>
    HTML

    expect(PrettyText.cook(raw)).to match_html(cooked)
  end

  it "sets the custom attribute on posts with policies" do
    SiteSetting.policy_restrict_to_staff_posts = false

    raw = <<~MD
      [policy group=staff reminder=weekly]
      I always open **doors**!
      [/policy]
    MD

    post = create_post(raw: raw)
    post = Post.find(post.id)

    expect(post.post_policy.groups.pluck(:name)).to eq(["staff"])

    post.revise(post.user, raw: "i am new raw")

    post = Post.find(post.id)

    expect(post.post_policy).to eq(nil)
  end

  it "allows policy to expire for end users on demand" do
    SiteSetting.policy_restrict_to_staff_posts = false

    freeze_time

    user = Fabricate(:admin)

    raw = <<~MD
      [policy group=staff renew=200]
      I always open **doors**!
      [/policy]
    MD

    post = create_post(raw: raw)
    PolicyUser.add!(user, post.post_policy)

    freeze_time(199.days.from_now)
    ::DiscoursePolicy::CheckPolicy.new.execute(nil)
    expect(post.post_policy.accepted_by).to eq([user])

    freeze_time(2.days.from_now)
    ::DiscoursePolicy::CheckPolicy.new.execute(nil)
    expect(post.post_policy.accepted_by).to be_empty
  end

  it "resets list of accepted users if version is bumped" do
    SiteSetting.policy_restrict_to_staff_posts = false

    freeze_time

    user = Fabricate(:admin)

    raw = <<~MD
      [policy group=staff reminder=weekly]
      I always open **doors**!
      [/policy]
    MD

    post = create_post(raw: raw)

    PolicyUser.add!(user, post.post_policy)

    post = Post.find(post.id)

    expect(post.post_policy.accepted_by).to contain_exactly(user)
    expect(post.post_policy.reminder).to eq("weekly")
    expect(post.post_policy.last_reminded_at).to eq_time(Time.zone.now)
    expect(post.post_policy.groups.pluck(:name)).to contain_exactly("staff")

    raw = <<~MD
      [policy groups=trust_level_1,trust_level_0 version=2 reminder=weekly]
      I always open **doors**!
      [/policy]
    MD

    post.revise(post.user, raw: raw)

    post = Post.find(post.id)
    expect(post.post_policy.accepted_by).to be_empty
    expect(post.post_policy.groups.pluck(:name)).to contain_exactly(
      "trust_level_0",
      "trust_level_1",
    )
  end
end
