require 'rails_helper'
require_dependency 'post_enqueuer'

describe PostEnqueuer do

  let(:user) { Fabricate(:user) }

  context 'with valid arguments' do
    let(:topic) { Fabricate(:topic) }
    let(:enqueuer) { PostEnqueuer.new(user, 'new_post') }

    it 'enqueues the post' do
      qp = enqueuer.enqueue(raw: 'This should be enqueued',
                            topic_id: topic.id,
                            post_options: { reply_to_post_number: 1 })

      expect(enqueuer.errors).to be_blank
      expect(qp).to be_present
      expect(qp.topic).to eq(topic)
      expect(qp.user).to eq(user)
      expect(UserAction.where(user_id: user.id, action_type: UserAction::PENDING).count).to eq(1)
    end
  end

  context "topic validations" do
    let(:enqueuer) { PostEnqueuer.new(user, 'new_topic') }

    it "doesn't enqueue the post" do
      qp = enqueuer.enqueue(raw: 'This should not be enqueued',
                            post_options: { title: 'too short' })

      expect(enqueuer.errors).to be_present
      expect(qp).to be_blank
    end
  end

  context "post validations" do
    let(:enqueuer) { PostEnqueuer.new(user, 'new_post') }

    it "doesn't enqueue the post" do
      qp = enqueuer.enqueue(raw: 'too short')

      expect(enqueuer.errors).to be_present
      expect(qp).to be_blank
    end
  end

end
