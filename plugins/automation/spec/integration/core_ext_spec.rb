# frozen_string_literal: true

describe "Core extensions" do
  fab!(:automation_1) { Fabricate(:automation) }
  fab!(:automation_2) { Fabricate(:automation) }

  describe "plugin_api" do
    describe "#add_triggerable_to_scriptable" do
      it "adds the triggerable as a possibility for a scriptable" do
        plugin = Plugin::Instance.new nil, "/tmp/test.rb"
        plugin.add_automation_triggerable(:bar) {}
        plugin.add_automation_scriptable(:foo) {}
        plugin.add_triggerable_to_scriptable(:foo, :bar)

        expect(DiscourseAutomation::Scriptable.plugin_triggerables[:bar]).to contain_exactly(:foo)
      end
    end

    describe "#add_automation_triggerable" do
      it "adds the triggerable" do
        plugin = Plugin::Instance.new nil, "/tmp/test.rb"
        plugin.add_automation_triggerable(:foo) {}

        expect(DiscourseAutomation::Triggerable.all).to include(:__triggerable_foo)
      end
    end

    describe "#add_automation_scriptable" do
      it "adds the scriptable" do
        plugin = Plugin::Instance.new nil, "/tmp/test.rb"
        plugin.add_automation_scriptable(:foo) {}

        expect(DiscourseAutomation::Scriptable.all).to include(:__scriptable_foo)
      end
    end
  end

  describe "post custom fields" do
    it "supports discourse_automation_ids" do
      post = create_post
      automation_1.add_id_to_custom_field(post, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)

      expect(post.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq(
        [automation_1.id],
      )

      automation_2.add_id_to_custom_field(post, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)

      expect(post.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq(
        [automation_1.id, automation_2.id],
      )

      PostCustomField.where(
        post_id: post.id,
        name: DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD,
      ).delete_all

      expect(post.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to be(nil)

      automation_1.add_id_to_custom_field(post, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)
      automation_1.add_id_to_custom_field(post, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)
      automation_1.add_id_to_custom_field(post, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)
      automation_1.add_id_to_custom_field(post, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)

      expect(post.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq(
        [automation_1.id],
      )

      automation_1.remove_id_from_custom_field(
        post,
        DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD,
      )

      expect(post.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq([])
    end
  end

  describe "topic custom fields" do
    it "supports discourse_automation_ids" do
      topic = create_topic
      automation_1.add_id_to_custom_field(topic, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)

      expect(topic.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq(
        [automation_1.id],
      )

      automation_2.add_id_to_custom_field(topic, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)

      expect(topic.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq(
        [automation_1.id, automation_2.id],
      )

      TopicCustomField.where(
        topic_id: topic.id,
        name: DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD,
      ).delete_all

      expect(topic.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq(
        nil,
      )

      automation_1.add_id_to_custom_field(topic, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)
      automation_1.add_id_to_custom_field(topic, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)
      automation_1.add_id_to_custom_field(topic, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)
      automation_1.add_id_to_custom_field(topic, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)

      expect(topic.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq(
        [automation_1.id],
      )

      automation_1.remove_id_from_custom_field(
        topic,
        DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD,
      )

      expect(topic.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq([])
    end
  end

  describe "user custom fields" do
    it "supports discourse_automation_ids" do
      SiteSetting.hide_email_address_taken = false

      user = create_user
      automation_1.add_id_to_custom_field(user, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)

      expect(user.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq(
        [automation_1.id],
      )

      automation_2.add_id_to_custom_field(user, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)

      expect(user.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq(
        [automation_1.id, automation_2.id],
      )

      UserCustomField.where(
        user_id: user.id,
        name: DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD,
      ).delete_all

      expect(user.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq(nil)

      automation_1.add_id_to_custom_field(user, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)
      automation_1.add_id_to_custom_field(user, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)
      automation_1.add_id_to_custom_field(user, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)
      automation_1.add_id_to_custom_field(user, DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD)

      expect(user.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq(
        [automation_1.id],
      )

      automation_1.remove_id_from_custom_field(
        user,
        DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD,
      )

      expect(user.reload.custom_fields[DiscourseAutomation::AUTOMATION_IDS_CUSTOM_FIELD]).to eq([])
    end
  end
end
