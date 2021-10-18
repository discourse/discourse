# frozen_string_literal: true

require_relative '../discourse_automation_helper'

describe 'Core extensions' do
  fab!(:automation_1) { Fabricate(:automation) }
  fab!(:automation_2) { Fabricate(:automation) }

  describe 'post custom fields' do
    it 'supports discourse_automation_ids' do
      post = create_post
      automation_1.attach_custom_field(post)

      expect(post.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to eq([automation_1.id])

      automation_2.attach_custom_field(post)

      expect(post.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to eq([automation_1.id, automation_2.id])

      PostCustomField.where(post_id: post.id, name: DiscourseAutomation::CUSTOM_FIELD).delete_all

      expect(post.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to be(nil)

      automation_1.attach_custom_field(post)
      automation_1.attach_custom_field(post)
      automation_1.attach_custom_field(post)
      automation_1.attach_custom_field(post)

      expect(post.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to eq([automation_1.id])

      automation_1.detach_custom_field(post)

      expect(post.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to be(nil)
    end
  end

  describe 'topic custom fields' do
    it 'supports discourse_automation_ids' do
      topic = create_topic
      automation_1.attach_custom_field(topic)

      expect(topic.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to eq([automation_1.id])

      automation_2.attach_custom_field(topic)

      expect(topic.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to eq([automation_1.id, automation_2.id])

      TopicCustomField.where(topic_id: topic.id, name: DiscourseAutomation::CUSTOM_FIELD).delete_all

      expect(topic.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to be(nil)

      automation_1.attach_custom_field(topic)
      automation_1.attach_custom_field(topic)
      automation_1.attach_custom_field(topic)
      automation_1.attach_custom_field(topic)

      expect(topic.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to eq([automation_1.id])

      automation_1.detach_custom_field(topic)

      expect(topic.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to be(nil)
    end
  end

  describe 'user custom fields' do
    it 'supports discourse_automation_ids' do
      user = create_user
      automation_1.attach_custom_field(user)

      expect(user.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to eq([automation_1.id])

      automation_2.attach_custom_field(user)

      expect(user.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to eq([automation_1.id, automation_2.id])

      UserCustomField.where(user_id: user.id, name: DiscourseAutomation::CUSTOM_FIELD).delete_all

      expect(user.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to be(nil)

      automation_1.attach_custom_field(user)
      automation_1.attach_custom_field(user)
      automation_1.attach_custom_field(user)
      automation_1.attach_custom_field(user)

      expect(user.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to eq([automation_1.id])

      automation_1.detach_custom_field(user)

      expect(user.reload.custom_fields[DiscourseAutomation::CUSTOM_FIELD]).to be(nil)
    end
  end
end
