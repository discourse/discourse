require 'rails_helper'

describe WebHookEventType do
  it { is_expected.to validate_presence_of :name }

  describe 'TopicType' do
    subject { WebHookEventType::TopicType }
    let(:topic) { Fabricate(:topic) }

    it 'loads the topic accordingly' do
      expect {
        subject.load_record(topic.id)
      }.not_to raise_error
    end

    it 'returns nil when topic is not found' do
      expect(subject.load_record(0)).to be_nil
    end
  end

  describe 'PostType' do
    subject { WebHookEventType::PostType }
    let(:post) { Fabricate(:post) }

    it 'loads the post accordingly' do
      expect {
        subject.load_record(post.id)
      }.not_to raise_error
    end

    it 'returns nil when post is not found' do
      expect(subject.load_record(0)).to be_nil
    end
  end

  describe 'UserType' do
    subject { WebHookEventType::UserType }
    let(:user) { Fabricate(:user) }

    it 'loads the user accordingly' do
      expect {
        subject.load_record(user.id)
      }.not_to raise_error
    end

    it 'returns nil when user is not found' do
      expect(subject.load_record(0)).to be_nil
    end
  end
end
