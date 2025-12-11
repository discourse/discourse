# frozen_string_literal: true

describe Jobs::DiscourseAutomation::SendFlagEmail do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  fab!(:email_template_automation_field) do
    field = nil

    Fabricate(
      :automation,
      script: DiscourseAutomation::Scripts::EMAIL_ON_FLAGGED_POST,
      trigger: DiscourseAutomation::Triggers::POST_FLAG_CREATED,
    ).tap do |automation|
      field =
        automation.upsert_field!(
          "email_template",
          "message",
          {
            value:
              I18n.t("discourse_automation.scriptables.email_on_flagged_post.default_template"),
          },
        )
    end

    field
  end

  fab!(:post_action) do
    Fabricate(:post_action, post:, post_action_type_id: PostActionType.types[:spam])
  end

  describe "#execute" do
    it "delivers email to the right recipient with the right subject and body" do
      expect do
        described_class.new.execute(
          email: "recipient@example.com",
          email_template_automation_field_id: email_template_automation_field.id,
          post_action_id: post_action.id,
        )
      end.to change { ActionMailer::Base.deliveries.size }.by(1)

      mail = ActionMailer::Base.deliveries.last

      expect(mail.subject).to eq(
        I18n.t(
          "discourse_automation.scriptables.email_on_flagged_post.subject",
          topic_title: topic.title,
          flagger_username: post_action.user.username,
        ),
      )

      expect(mail.body.to_s).to eq(<<~BODY.chomp)
        A post has been flagged.

        Topic: #{topic.title} (#{topic.url})
        Post: #{post.full_url} (##{post.post_number})
        Flag type: #{PostActionTypeView.new.names[post_action.post_action_type_id]}
        Flagged user: #{post.user.username}
        Flagged by: #{post_action.user.username}
        Category: #{post.topic.category.name}
        Tags: #{post.topic.tags.pluck(:name).join(", ")}

        --------
        Post excerpt:
        #{post.excerpt_for_topic}
      BODY
    end

    it "does not deliver email if `post_action_id` is invalid" do
      expect do
        described_class.new.execute(
          email: "recipient@example.com",
          email_template_automation_field_id: email_template_automation_field.id,
          post_action_id: -999_999,
        )
      end.not_to change { ActionMailer::Base.deliveries.size }
    end

    it "does not deliver email if post associated with the post action has been destroyed" do
      post_action.post.destroy!

      expect do
        described_class.new.execute(
          email: "recipient@example.com",
          email_template_automation_field_id: email_template_automation_field.id,
          post_action_id: post_action.id,
        )
      end.not_to change { ActionMailer::Base.deliveries.size }
    end
  end
end
