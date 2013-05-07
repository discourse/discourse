require 'spec_helper'
require 'jobs'

describe Jobs::CloseTopic do

  let(:admin) { Fabricate.build(:admin) }

  it 'closes a topic that is set to auto-close' do
    topic = Fabricate.build(:topic, auto_close_at: Time.zone.now, user: admin)
    topic.expects(:update_status).with('autoclosed', true, admin)
    Topic.stubs(:find).returns(topic)
    User.stubs(:find).returns(admin)
    Jobs::CloseTopic.new.execute( topic_id: 123, user_id: 234 )
  end

  it 'does nothing if the topic is not set to auto-close' do
    topic = Fabricate.build(:topic, auto_close_at: nil, user: admin)
    topic.expects(:update_status).never
    Topic.stubs(:find).returns(topic)
    User.stubs(:find).returns(admin)
    Jobs::CloseTopic.new.execute( topic_id: 123, user_id: 234 )
  end

  it 'does nothing if the user is not authorized to close the topic' do
    topic = Fabricate.build(:topic, auto_close_at: Time.zone.now, user: admin)
    topic.expects(:update_status).never
    Topic.stubs(:find).returns(topic)
    User.stubs(:find).returns(admin)
    Guardian.any_instance.stubs(:can_moderate?).returns(false)
    Jobs::CloseTopic.new.execute( topic_id: 123, user_id: 234 )
  end

  it 'does nothing if the topic is already closed'

end