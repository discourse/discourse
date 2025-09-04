# frozen_string_literal: true

describe DiscourseAutomation::EventHandlers do
  before { SiteSetting.discourse_automation_enabled = true }

  describe "#handle_stalled_topic" do
    context "when tags are empty" do
      fab!(:automation) do
        Fabricate(:automation, trigger: DiscourseAutomation::Triggers::STALLED_TOPIC, enabled: true)
      end
      fab!(:user)
      fab!(:post) { Fabricate(:post, user: user) }

      before do
        automation.upsert_field!("tags", "tags", { value: [] }, target: "trigger")
        Fabricate(:user_global_notice, identifier: automation.id, user_id: user.id)
      end

      it "destroys notices" do
        expect { DiscourseAutomation::EventHandlers.handle_stalled_topic(post) }.to change {
          DiscourseAutomation::UserGlobalNotice.count
        }.by(-1)
      end
    end
  end

  describe "#handle_topic_closed" do
    fab!(:automation) do
      Fabricate(:automation, trigger: DiscourseAutomation::Triggers::TOPIC_CLOSED, enabled: true)
    end
    fab!(:topic) { Fabricate(:post).topic }

    it "triggers automation when a topic is closed" do
      list =
        capture_contexts do
          TopicStatusUpdater.new(topic, Fabricate(:admin)).update!("closed", true)
        end

      expect(list.size).to eq(1)
      expect(list.first["kind"]).to eq("topic_closed")
      expect(list.first["topic"].id).to eq(topic.id)
      expect(list.first["placeholders"]["topic_url"]).to eq(topic.relative_url)
      expect(list.first["placeholders"]["topic_title"]).to eq(topic.title)
    end
  end
end
