# frozen_string_literal: true

describe "EmailOnFlaggedPost" do
  fab!(:recipient) { Fabricate(:user, email: "recipient@example.com") }
  fab!(:user_2, :user)
  fab!(:flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:second_flagger) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scripts::EMAIL_ON_FLAGGED_POST,
      trigger: DiscourseAutomation::Triggers::POST_FLAG_CREATED,
    )
  end

  before do
    SiteSetting.discourse_automation_enabled = true
    SiteSetting.disable_emails = "no"
  end

  it "rejects email addresses that are invalid" do
    automation.upsert_field!("recipients", "users", { value: ["@invalid-email"] })

    expect do
      result = PostActionCreator.spam(flagger, post)
      expect(result.success).to eq(true)
    end.to change { Jobs::DiscourseAutomation::SendFlagEmail.jobs.length }.by(0)
  end

  it "rejects usernames that do not exist" do
    automation.upsert_field!("recipients", "users", { value: ["nonexistent_user"] })

    expect do
      result = PostActionCreator.spam(flagger, post)
      expect(result.success).to eq(true)
    end.to change { Jobs::DiscourseAutomation::SendFlagEmail.jobs.length }.by(0)
  end

  it "enqueues a job per recipient with placeholders applied" do
    automation.upsert_field!("recipients", "users", { value: [recipient.email, user_2.username] })

    field =
      automation.upsert_field!(
        "email_template",
        "message",
        {
          value: I18n.t("discourse_automation.scriptables.email_on_flagged_post.default_template"),
        },
      )

    result = nil

    expect do
      result = PostActionCreator.spam(flagger, post)
      expect(result.success).to eq(true)
    end.to change { Jobs::DiscourseAutomation::SendFlagEmail.jobs.length }.by(2)

    expect_job_enqueued(
      job: Jobs::DiscourseAutomation::SendFlagEmail,
      args: {
        email: recipient.email,
        email_template_automation_field_id: field.id,
        post_action_id: result.post_action.id,
      },
    )

    expect_job_enqueued(
      job: Jobs::DiscourseAutomation::SendFlagEmail,
      args: {
        email: user_2.primary_email.email,
        email_template_automation_field_id: field.id,
        post_action_id: result.post_action.id,
      },
    )
  end
end
