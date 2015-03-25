require 'spec_helper'
require_dependency 'queued_post'

describe QueuedPost do

  context "creating a post" do
    let(:topic) { Fabricate(:topic) }
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }
    let(:qp) { QueuedPost.create(queue: 'new_post',
                                 state: QueuedPost.states[:new],
                                 user_id: user.id,
                                 topic_id: topic.id,
                                 raw: 'This post should be queued up',
                                 post_options: {
                                   reply_to_post_number: 1,
                                   via_email: true,
                                   raw_email: 'store_me',
                                   auto_track: true,
                                   custom_fields: { hello: 'world' },
                                   cooking_options: { cat: 'hat' },
                                   cook_method: 'regular',
                                   not_create_option: true,
                                   image_sizes: {"http://foo.bar/image.png" => {"width" => 0, "height" => 222}}
                                 }) }

    it "returns the appropriate options for posting" do
      create_options = qp.create_options

      expect(create_options[:topic_id]).to eq(topic.id)
      expect(create_options[:raw]).to eq('This post should be queued up')
      expect(create_options[:reply_to_post_number]).to eq(1)
      expect(create_options[:via_email]).to eq(true)
      expect(create_options[:raw_email]).to eq('store_me')
      expect(create_options[:auto_track]).to eq(true)
      expect(create_options[:custom_fields]).to eq('hello' => 'world')
      expect(create_options[:cooking_options]).to eq('cat' => 'hat')
      expect(create_options[:cook_method]).to eq('regular')
      expect(create_options[:not_create_option]).to eq(nil)
      expect(create_options[:image_sizes]).to eq("http://foo.bar/image.png" => {"width" => 0, "height" => 222})
    end

    it "follows the correct workflow for approval" do
      post = qp.approve!(admin)

      # Creates the post with the attributes
      expect(post).to be_present
      expect(post).to be_valid
      expect(post.topic).to eq(topic)

      # Updates the QP record
      expect(qp.approved_by).to eq(admin)
      expect(qp.state).to eq(QueuedPost.states[:approved])
      expect(qp.approved_at).to be_present

      # We can't approve twice
      expect(-> { qp.approve!(admin) }).to raise_error(QueuedPost::InvalidStateTransition)

    end

    it "follows the correct workflow for rejection" do
      qp.reject!(admin)

      # Updates the QP record
      expect(qp.rejected_by).to eq(admin)
      expect(qp.state).to eq(QueuedPost.states[:rejected])
      expect(qp.rejected_at).to be_present

      # We can't reject twice
      expect(-> { qp.reject!(admin) }).to raise_error(QueuedPost::InvalidStateTransition)
    end
  end

  context "creating a topic" do
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }
    let!(:category) { Fabricate(:category) }

    let(:qp) { QueuedPost.create(queue: 'new_topic',
                                 state: QueuedPost.states[:new],
                                 user_id: user.id,
                                 raw: 'This post should be queued up',
                                 post_options: {
                                   title: 'This is the topic title to queue up',
                                   archetype: 'regular',
                                   category: category.id,
                                   meta_data: {evil: 'trout'}
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
    end

    it "doesn't create the post and topic" do
      topic_count, post_count = Topic.count, Post.count

      qp.reject!(admin)

      expect(Topic.count).to eq(topic_count)
      expect(Post.count).to eq(post_count)
    end
  end

end
