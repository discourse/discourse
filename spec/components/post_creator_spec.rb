require 'spec_helper'
require 'post_creator'
require 'topic_subtype'

describe PostCreator do

  let(:user) { Fabricate(:user) }

  it 'raises an error without a raw value' do
    lambda { PostCreator.new(user, {}) }.should raise_error(Discourse::InvalidParameters)
  end

  context 'new topic' do
    let(:category) { Fabricate(:category, user: user) }
    let(:topic) { Fabricate(:topic, user: user) }
    let(:basic_topic_params) { {title: 'hello world topic', raw: 'my name is fred', archetype_id: 1} }
    let(:image_sizes) { {'http://an.image.host/image.jpg' => {'width' => 111, 'height' => 222}} }

    let(:creator) { PostCreator.new(user, basic_topic_params) }
    let(:creator_with_category) { PostCreator.new(user, basic_topic_params.merge(category: category.name )) }
    let(:creator_with_meta_data) { PostCreator.new(user, basic_topic_params.merge(meta_data: {hello: 'world'} )) }
    let(:creator_with_image_sizes) { PostCreator.new(user, basic_topic_params.merge(image_sizes: image_sizes)) }

    it 'ensures the user can create the topic' do
      Guardian.any_instance.expects(:can_create?).with(Topic,nil).returns(false)
      lambda { creator.create }.should raise_error(Discourse::InvalidAccess)
    end

    context 'success' do
      it 'creates a topic' do
        lambda { creator.create }.should change(Topic, :count).by(1)
      end

      it 'returns a post' do
        creator.create.is_a?(Post).should be_true
      end

      it 'extracts links from the post' do
        TopicLink.expects(:extract_from).with(instance_of(Post))
        creator.create
      end

      it 'enqueues the post on the message bus' do
        MessageBus.stubs(:publish).with("/users/#{user.username}", anything)
        MessageBus.expects(:publish).with("/topic/#{topic.id}", instance_of(Hash))
        PostCreator.new(user, raw: basic_topic_params[:raw], topic_id: topic.id)
      end

      it 'features topic users' do
        Jobs.stubs(:enqueue).with(:process_post, anything)
        Jobs.expects(:enqueue).with(:feature_topic_users, has_key(:topic_id))
        creator.create
      end

      it 'queues up post processing job when saved' do
        Jobs.stubs(:enqueue).with(:feature_topic_users, has_key(:topic_id))
        Jobs.expects(:enqueue).with(:process_post, has_key(:post_id))
        creator.create
      end

      it 'passes the invalidate_oneboxes along to the job if present' do
        Jobs.stubs(:enqueue).with(:feature_topic_users, has_key(:topic_id))
        Jobs.expects(:enqueue).with(:process_post, has_key(:invalidate_oneboxes))
        creator.opts[:invalidate_oneboxes] = true
        creator.create
      end

      it 'passes the image_sizes along to the job if present' do
        Jobs.stubs(:enqueue).with(:feature_topic_users, has_key(:topic_id))
        Jobs.expects(:enqueue).with(:process_post, has_key(:image_sizes))
        creator.opts[:image_sizes] = {'http://an.image.host/image.jpg' => {'width' => 17, 'height' => 31}}
        creator.create
      end

      it 'assigns a category when supplied' do
        creator_with_category.create.topic.category.should == category
      end

      it 'adds  meta data from the post' do
        creator_with_meta_data.create.topic.meta_data['hello'].should == 'world'
      end

      it 'passes the image sizes through' do
        Post.any_instance.expects(:image_sizes=).with(image_sizes)
        creator_with_image_sizes.create
      end

      it 'increases topic response counts' do
        first_post = creator.create
        user2 = Fabricate(:coding_horror)

        user2.topic_reply_count.should == 0
        first_post.user.reload.topic_reply_count.should == 0

        PostCreator.new(user2, topic_id: first_post.topic_id, raw: "this is my test post 123").create
        user2.reload.topic_reply_count.should == 1
        first_post.user.reload.topic_reply_count.should == 0
      end
    end

  end

  context 'uniqueness' do

    let!(:topic) { Fabricate(:topic, user: user) }
    let(:basic_topic_params) { { raw: 'test reply', topic_id: topic.id, reply_to_post_number: 4} }
    let(:creator) { PostCreator.new(user, basic_topic_params) }

    context "disabled" do
      before do
        SiteSetting.stubs(:unique_posts_mins).returns(0)
        creator.create
      end

      it "returns true for another post with the same content" do
        new_creator = PostCreator.new(user, basic_topic_params)
        new_creator.create.should be_present
      end
    end

    context 'enabled' do
      let(:new_post_creator) { PostCreator.new(user, basic_topic_params) }

      before do
        SiteSetting.stubs(:unique_posts_mins).returns(10)
        creator.create
      end

      it "returns blank for another post with the same content" do
        new_post_creator.create
        new_post_creator.errors.should be_present
      end

      it "returns a post for admins" do
        user.admin = true
        new_post_creator.create
        new_post_creator.errors.should be_blank
      end

      it "returns a post for moderators" do
        user.moderator = true
        new_post_creator.create
        new_post_creator.errors.should be_blank
      end
    end

  end

  # more integration testing ... maximise our testing
  context 'existing topic' do
    let!(:topic) { Fabricate(:topic, user: user) }
    let(:creator) { PostCreator.new(user, raw: 'test reply', topic_id: topic.id, reply_to_post_number: 4) }

    it 'ensures the user can create the post' do
      Guardian.any_instance.expects(:can_create?).with(Post, topic).returns(false)
      lambda { creator.create }.should raise_error(Discourse::InvalidAccess)
    end

    context 'success' do
      it 'create correctly' do
        post = creator.create
        Post.count.should == 1
        Topic.count.should == 1
        post.reply_to_post_number.should == 4
      end

    end

  end

  # integration test ... minimise db work
  context 'private message' do
    let(:target_user1) { Fabricate(:coding_horror) }
    let(:target_user2) { Fabricate(:moderator) }
    let(:unrelated) { Fabricate(:user) }
    let(:post) do
      PostCreator.create(user, title: 'hi there welcome to my topic',
                               raw: "this is my awesome message @#{unrelated.username_lower}",
                               archetype: Archetype.private_message,
                               target_usernames: [target_user1.username, target_user2.username].join(','))
    end

    it 'acts correctly' do
      post.topic.archetype.should == Archetype.private_message
      post.topic.topic_allowed_users.count.should == 3

      # does not notify an unrelated user
      unrelated.notifications.count.should == 0
      post.topic.subtype.should == TopicSubtype.user_to_user
    end
  end

  context 'private message to group' do
    let(:target_user1) { Fabricate(:coding_horror) }
    let(:target_user2) { Fabricate(:moderator) }
    let(:group) do
      g = Fabricate.build(:group)
      g.add(target_user1)
      g.add(target_user2)
      g.save
      g
    end
    let(:unrelated) { Fabricate(:user) }
    let(:post) do
      PostCreator.create(user, title: 'hi there welcome to my topic',
                               raw: "this is my awesome message @#{unrelated.username_lower}",
                               archetype: Archetype.private_message,
                               target_group_names: group.name)
    end

    it 'acts correctly' do
      post.topic.archetype.should == Archetype.private_message
      post.topic.topic_allowed_users.count.should == 1
      post.topic.topic_allowed_groups.count.should == 1

      # does not notify an unrelated user
      unrelated.notifications.count.should == 0
      post.topic.subtype.should == TopicSubtype.user_to_user
      target_user1.notifications.count.should == 1
      target_user2.notifications.count.should == 1
    end
  end
end

