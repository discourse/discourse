# frozen_string_literal: true

describe DiscourseAutomation::EventHandlers do
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
end
