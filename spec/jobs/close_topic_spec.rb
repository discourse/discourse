require 'rails_helper'
require_dependency 'jobs/base'

describe Jobs::CloseTopic do

  let(:admin) { Fabricate.build(:admin) }

  it 'closes a topic that is set to auto-close' do
    topic = Fabricate.build(:topic, auto_close_at: Time.zone.now, user: admin)
    topic.expects(:update_status).with('autoclosed', true, admin)
    Topic.stubs(:find_by).returns(topic)
    User.stubs(:find_by).returns(admin)
    Jobs::CloseTopic.new.execute( topic_id: 123, user_id: 234 )
  end

  shared_examples_for "cases when CloseTopic does nothing" do
    it 'does nothing to the topic' do
      topic.expects(:update_status).never
      Topic.stubs(:find_by).returns(topic)
      User.stubs(:find_by).returns(admin)
      Jobs::CloseTopic.new.execute( topic_id: 123, user_id: 234 )
    end
  end

  context 'when topic is not set to auto-close' do
    subject(:topic) { Fabricate.build(:topic, auto_close_at: nil, user: admin) }
    it_behaves_like 'cases when CloseTopic does nothing'
  end

  context 'when user is not authorized to close topics' do
    subject(:topic) { Fabricate.build(:topic, auto_close_at: 2.days.from_now, user: admin) }
    before { Guardian.any_instance.stubs(:can_moderate?).returns(false) }
    it_behaves_like 'cases when CloseTopic does nothing'
  end

  context 'the topic is already closed' do
    subject(:topic) { Fabricate.build(:topic, auto_close_at: 2.days.from_now, user: admin, closed: true) }
    it_behaves_like 'cases when CloseTopic does nothing'
  end

  context 'the topic has been deleted' do
    subject(:topic) { Fabricate.build(:deleted_topic, auto_close_at: 2.days.from_now, user: admin) }
    it_behaves_like 'cases when CloseTopic does nothing'
  end

end
