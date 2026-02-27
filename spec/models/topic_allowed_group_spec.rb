# frozen_string_literal: true

RSpec.describe TopicAllowedGroup do
  it { is_expected.to belong_to :topic }
  it { is_expected.to belong_to :group }

  describe "cleanup_inaccessible_notifications" do
    it "enqueues DeleteInaccessibleNotifications when destroyed" do
      group = Fabricate(:group)
      pm = Fabricate(:private_message_topic)
      topic_allowed_group = TopicAllowedGroup.create!(topic: pm, group: group)

      topic_allowed_group.destroy!

      expect_job_enqueued(job: :delete_inaccessible_notifications, args: { topic_id: pm.id })
    end
  end
end
