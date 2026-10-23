# frozen_string_literal: true

RSpec.describe Jobs::Boards::SyncTopic do
  fab!(:topic)

  before { enable_current_plugin }

  describe "#execute" do
    it "syncs the topic" do
      Boards::TopicSync.expects(:sync_topic).with(topic)

      described_class.new.execute(topic_id: topic.id)
    end

    it "does nothing when the plugin is disabled" do
      SiteSetting.boards_enabled = false
      Boards::TopicSync.expects(:sync_topic).never

      described_class.new.execute(topic_id: topic.id)
    end

    it "does nothing when no topic_id is given" do
      Boards::TopicSync.expects(:sync_topic).never

      described_class.new.execute(topic_id: nil)
    end

    it "does nothing when the topic no longer exists" do
      Boards::TopicSync.expects(:sync_topic).never

      described_class.new.execute(topic_id: topic.id + 1000)
    end
  end
end
