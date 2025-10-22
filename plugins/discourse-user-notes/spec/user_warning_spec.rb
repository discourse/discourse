# frozen_string_literal: true

describe UserWarning do
  let(:user) { Fabricate(:user) }
  let(:admin) { Fabricate(:admin) }
  let(:category) { Fabricate(:category) }
  let(:topic) { Fabricate(:topic, category: category) }

  describe "when a user warning is created" do
    context "when staff notes plugin is enabled" do
      before { SiteSetting.user_notes_enabled = true }

      it "should create staff note for warning" do
        UserWarning.create(topic_id: topic.id, user_id: user.id, created_by_id: admin.id)

        expect(PluginStore.get("user_notes", "notes:#{user.id}")).to be_present
      end

      it "should use system language" do
        freeze_time

        warning = UserWarning.create!(topic_id: topic.id, user_id: user.id, created_by_id: admin.id)
        warning.destroy!

        I18n.with_locale(:fr) do # Simulate request from french user
          UserWarning.create(topic_id: topic.id, user_id: user.id, created_by_id: admin.id)
        end

        notes = PluginStore.get("user_notes", "notes:#{user.id}")
        expect(notes[0]["raw"]).to eq(notes[1]["raw"])
      end

      it "should trigger user_warning_created event" do
        callback_called = false

        event_handler = Proc.new { |warning| callback_called = true }

        DiscourseEvent.on(:user_warning_created, &event_handler)

        begin
          UserWarning.create!(topic_id: topic.id, user_id: user.id, created_by_id: admin.id)
          expect(callback_called).to be true
        ensure
          # Clean up event listener
          DiscourseEvent.off(:user_warning_created, &event_handler)
        end
      end
    end
  end
end
