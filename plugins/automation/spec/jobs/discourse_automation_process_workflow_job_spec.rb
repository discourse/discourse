# frozen_string_literal: true

require 'rails_helper'

describe Jobs::DiscourseAutomationProcessWorkflow do
  fab!(:user) { Fabricate(:user) }

  before do
    DiscourseAutomation.reset!

    DiscourseAutomation::Triggerable.add(:group_joined) do
      field :user, type: :user

      placeholder :username
      provided :user

      trigger? do |args, options|
        true
      end
    end

    DiscourseAutomation::Plannable.add(:send_personal_message) do
      field :receiver_username, type: :user
      field :sender_username, type: :user

      placeholder :sender_username

      plan! do |options, args|
        user_id = args.dig(:trigger, :args, :user_id)
        if user_id
          options["sender_username"] = User.find(user_id).username
        end
      end
    end
  end

  it "works" do
    workflow = DiscourseAutomation::Workflow.create!(name: "foo")
    DiscourseAutomation::Trigger.create!(
      type: :group_joined,
      workflow: workflow
    )
    DiscourseAutomation::Plan.create!(
      type: :send_personal_message,
      workflow: workflow,
      options: {
        receiver_username: "arpit",
        sender_username: "johani"
      }
    )

    Sidekiq::Testing.inline! do
      Jobs.enqueue(
        :discourse_automation_process_workflow,
        workflow_id: workflow.id,
        user_id: user.id
      )
    end
  end
end
