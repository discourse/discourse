require 'rails_helper'
require_dependency 'queued_post'

describe QueuedPost do

  describe '#states' do
    context "verify enum sequence" do
      before do
        @states = QueuedPost.states
      end

      it "'new' should be at 1st position" do
        expect(@states[:new]).to eq(1)
      end

      it "'rejected' should be at 3rd position" do
        expect(@states[:rejected]).to eq(3)
      end
    end
  end

  context "creating a post" do
    let(:topic) { Fabricate(:topic) }
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }
    let(:qp) { Fabricate(:queued_post, topic: topic, user: user) }

    it "returns the appropriate options for posting" do
      create_options = qp.create_options

      expect(create_options[:topic_id]).to eq(topic.id)
      expect(create_options[:raw]).to eq('This post should be queued up')
      expect(create_options[:reply_to_post_number]).to eq(1)
      expect(create_options[:via_email]).to eq(true)
      expect(create_options[:raw_email]).to eq('store_me')
      expect(create_options[:auto_track]).to eq(true)
      expect(create_options[:custom_fields]).to eq('hello' => 'world')
      expect(create_options[:cooking_options]).to eq(cat: 'hat')
      expect(create_options[:cook_method]).to eq(Post.cook_methods[:raw_html])
      expect(create_options[:not_create_option]).to eq(nil)
      expect(create_options[:image_sizes]).to eq("http://foo.bar/image.png" => { "width" => 0, "height" => 222 })
    end

    it "follows the correct workflow for approval" do
      qp.create_pending_action
      post = qp.approve!(admin)

      # Creates the post with the attributes
      expect(post).to be_present
      expect(post).to be_valid
      expect(post.topic).to eq(topic)
      expect(post.custom_fields['hello']).to eq('world')

      # Updates the QP record
      expect(qp.approved_by).to eq(admin)
      expect(qp.state).to eq(QueuedPost.states[:approved])
      expect(qp.approved_at).to be_present

      # It removes the pending action
      expect(UserAction.where(queued_post_id: qp.id).count).to eq(0)

      # We can't approve twice
      expect(-> { qp.approve!(admin) }).to raise_error(QueuedPost::InvalidStateTransition)
    end

    it "skips validations" do
      qp.post_options[:title] = 'too short'
      post = qp.approve!(admin)
      expect(post).to be_present
    end

    it "logs post approvals" do
      qp.approve!(admin)
      expect(UserHistory.where(action: UserHistory.actions[:post_approved]).count).to eq(1)
    end

    it "follows the correct workflow for rejection" do
      qp.create_pending_action
      qp.reject!(admin)

      # Updates the QP record
      expect(qp.rejected_by).to eq(admin)
      expect(qp.state).to eq(QueuedPost.states[:rejected])
      expect(qp.rejected_at).to be_present

      # It removes the pending action
      expect(UserAction.where(queued_post_id: qp.id).count).to eq(0)

      # Logs staff action for rejected post
      post_rejected_logs = UserHistory.where(action: UserHistory.actions[:post_rejected])
      expect(post_rejected_logs.count).to eq(1)
      expect(post_rejected_logs.first.details).to include(qp.raw)

      # We can't reject twice
      expect(-> { qp.reject!(admin) }).to raise_error(QueuedPost::InvalidStateTransition)
    end
  end

  context "creating a topic" do
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }

    context "with a valid topic" do
      let!(:category) { Fabricate(:category) }
      let(:qp) { QueuedPost.create(queue: 'eviltrout',
                                   state: QueuedPost.states[:new],
                                   user_id: user.id,
                                   raw: 'This post should be queued up',
                                   post_options: {
                                     title: 'This is the topic title to queue up',
                                     archetype: 'regular',
                                     category: category.id,
                                     meta_data: { evil: 'trout' }
                                   }) }

      it "returns the appropriate options for creating a topic" do
        create_options = qp.create_options

        expect(create_options[:category]).to eq(category.id)
        expect(create_options[:archetype]).to eq('regular')
        expect(create_options[:meta_data]).to eq('evil' => 'trout')
      end

      it "creates the post and topic" do
        topic_count, post_count = Topic.count, Post.count
        post = qp.approve!(admin)

        expect(Topic.count).to eq(topic_count + 1)
        expect(Post.count).to eq(post_count + 1)

        expect(post).to be_present
        expect(post).to be_valid

        topic = post.topic
        expect(topic).to be_present
        expect(topic.category).to eq(category)

        expect(UserHistory.where(action: UserHistory.actions[:post_approved]).count).to eq(1)
      end

      it "rejecting doesn't create the post and topic" do
        topic_count, post_count = Topic.count, Post.count

        qp.reject!(admin)

        expect(Topic.count).to eq(topic_count)
        expect(Post.count).to eq(post_count)
      end
    end
  end

  context "visibility" do
    it "works as expected in the invisible queue" do
      qp = Fabricate(:queued_post, queue: 'invisible')
      expect(qp).to_not be_visible
      expect(QueuedPost.visible).to_not include(qp)
      expect(QueuedPost.new_count).to eq(0)
    end

    it "works as expected in the visible queue" do
      qp = Fabricate(:queued_post, queue: 'default')
      expect(qp).to be_visible
      expect(QueuedPost.visible).to include(qp)
      expect(QueuedPost.new_count).to eq(1)
    end
  end

  describe 'create' do
    subject { Fabricate.build(:queued_post) }

    it 'triggers a extensibility event' do
      event = DiscourseEvent.track_events { subject.save! }.first

      expect(event[:event_name]).to eq(:queued_post_created)
      expect(event[:params].first).to eq(subject)
    end
  end

  describe 'approve' do
    subject { Fabricate(:queued_post) }

    it 'triggers a extensibility event' do
      event = DiscourseEvent.track_events { subject.approve!(Discourse.system_user) }.last

      expect(event[:event_name]).to eq(:approved_post)
      expect(event[:params].first).to eq(subject)
    end
  end

  describe 'reject' do
    subject { Fabricate(:queued_post) }

    it 'triggers a extensibility event' do
      event = DiscourseEvent.track_events { subject.reject!(Discourse.system_user) }.last

      expect(event[:event_name]).to eq(:rejected_post)
      expect(event[:params].first).to eq(subject)
    end
  end

end
