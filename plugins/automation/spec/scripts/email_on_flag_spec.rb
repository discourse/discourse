# frozen_string_literal: true

describe "EmailOnFlag" do
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

    ActionMailer::Base.deliveries.clear
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
    result = PostActionCreator.spam(flagger, post)
    expect(result.success).to eq(true)

    expect { run_script(result.post_action) }.to change { ActionMailer::Base.deliveries.size }.by(1)

    mail = ActionMailer::Base.deliveries.last

    expect(mail.to).to contain_exactly(recipient.email)
    expect(mail.subject).to include(post.topic.title)

    expect(mail.body.encoded).to include(flagger.username)
    expect(mail.body.encoded).to include(post.excerpt(300, strip_links: true))
    expect(mail.body.encoded).to include("#{Discourse.base_url}#{post.topic.relative_url}")
  end
end
