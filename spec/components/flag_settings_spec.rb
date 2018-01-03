require 'rails_helper'
require 'flag_settings'

RSpec.describe FlagSettings do

  let(:settings) { FlagSettings.new }

  describe 'add' do
    it 'will add a type' do
      settings.add(3, :off_topic)
      expect(settings.flag_types).to include(:off_topic)
      expect(settings.is_flag?(:off_topic)).to eq(true)
      expect(settings.is_flag?(:vote)).to eq(false)

      expect(settings.topic_flag_types).to be_empty
      expect(settings.notify_types).to be_empty
      expect(settings.auto_action_types).to be_empty
    end

    it 'will add a topic type' do
      settings.add(4, :inappropriate, topic_type: true)
      expect(settings.flag_types).to include(:inappropriate)
      expect(settings.topic_flag_types).to include(:inappropriate)
      expect(settings.without_custom_types).to include(:inappropriate)
    end

    it 'will add a notify type' do
      settings.add(3, :off_topic, notify_type: true)
      expect(settings.flag_types).to include(:off_topic)
      expect(settings.notify_types).to include(:off_topic)
    end

    it 'will add an auto action type' do
      settings.add(7, :notify_moderators, auto_action_type: true)
      expect(settings.flag_types).to include(:notify_moderators)
      expect(settings.auto_action_types).to include(:notify_moderators)
    end

    it 'will add a custom type' do
      settings.add(7, :notify_user, custom_type: true)
      expect(settings.flag_types).to include(:notify_user)
      expect(settings.custom_types).to include(:notify_user)
      expect(settings.without_custom_types).to be_empty
    end
  end
end
