# frozen_string_literal: true

describe "EmailOnFlag" do
  before do
    SiteSetting.discourse_automation_enabled = true
    SiteSetting.disable_emails = "no"
  end

  fab!(:recipient) { Fabricate(:user, email: "recipient@example.com") }
  fab!(:flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:second_flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:post)

  fab!(:automation) do
    Fabricate(
      :automation,
      script: "email_on_flag",
      trigger: DiscourseAutomation::Triggers::FLAG_CREATED,
    )
  end

  before do
    SiteSetting.discourse_automation_enabled = true
    SiteSetting.disable_emails = "no"

    automation.upsert_field!("recipients", "email_group_user", { value: [recipient.email] })
    automation.upsert_field!(
      "email_template",
      "message",
      {
        value:
          "Flagged by %%FLAGGER_USERNAME%% on %%TOPIC_TITLE%%\n%%TOPIC_URL%%\n%%POST_EXCERPT%%",
      },
    )
    automation.reload
    expect(automation.serialized_fields["recipients"]).to be_present
    expect(automation.scriptable.not_found).to eq(false)
  end

  def run_script(post_action)
    fields = automation.serialized_fields
    flag_type = fields.dig("flag_type", "value")
    return if flag_type.present? && flag_type != post_action.post_action_type_id

    automation.scriptable.script.call(
      { "post_action" => post_action, "post" => post_action.post },
      fields,
      automation,
    )
  end

  it "sends an email with placeholders applied" do
    sent = []
    allow(DiscourseAutomation::FlagMailer).to receive(
      :send_flag_email,
    ).and_wrap_original do |m, *args, **kw|
      sent << { to: args.first, subject: kw[:subject], body: kw[:body] }
      double(deliver_now: true)
    end

    result = PostActionCreator.spam(flagger, post)
    expect(result.success).to eq(true)

    run_script(result.post_action)
    expect(sent.length).to eq(1)
    expect(sent.first[:to]).to eq(recipient.email)
    expect(sent.first[:subject]).to include(post.topic.title)
    expect(sent.first[:body]).to include(flagger.username)
    expect(sent.first[:body]).to include(post.excerpt(300, strip_links: true))
    expect(sent.first[:body]).to include("#{Discourse.base_url}#{post.topic.relative_url}")
  end

  it "respects flag type trigger filter" do
    sent = []
    allow(DiscourseAutomation::FlagMailer).to receive(
      :send_flag_email,
    ).and_wrap_original do |m, *args, **kw|
      sent << { to: args.first, subject: kw[:subject], body: kw[:body] }
      double(deliver_now: true)
    end

    automation.upsert_field!(
      "flag_type",
      "choices",
      { value: PostActionType.types[:off_topic] },
      target: "trigger",
    )

    result = PostActionCreator.spam(flagger, post)
    expect(result.success).to eq(true)
    run_script(result.post_action)
    expect(sent).to be_empty

    result = PostActionCreator.off_topic(second_flagger, post)
    expect(result.success).to eq(true)
    run_script(result.post_action)
    expect(sent.length).to eq(1)
  end
end
