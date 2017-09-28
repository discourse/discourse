require 'rails_helper'

describe TopicViewSerializer do
  let(:topic) { Fabricate(:topic) }
  let(:user) { Fabricate(:user) }

  describe '#suggested_topics' do
    let(:topic2) { Fabricate(:topic) }

    before do
      TopicUser.update_last_read(user, topic2.id, 0, 0)
    end

    describe 'when loading last chunk' do
      it 'should include suggested topics' do
        topic_view = TopicView.new(topic.id, user)
        json = described_class.new(topic_view, scope: Guardian.new(user), root: false).as_json

        expect(json[:suggested_topics].first.id).to eq(topic2.id)
      end
    end

    describe 'when not loading last chunk' do
      let(:post) { Fabricate(:post, topic: topic) }
      let(:post2) { Fabricate(:post, topic: topic) }

      it 'should not include suggested topics' do
        post
        post2
        topic_view = TopicView.new(topic.id, user, post_ids: [post.id])
        topic_view.next_page
        json = described_class.new(topic_view, scope: Guardian.new(user), root: false).as_json

        expect(json[:suggested_topics]).to eq(nil)
      end
    end
  end
end
