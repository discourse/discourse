require 'spec_helper'
require 'post_creator'
require 'topic_subtype'

describe PostCreator do

  before do
    ActiveRecord::Base.observers.enable :all
  end

  let(:user) { Fabricate(:user) }

  context "new topic" do
    let(:category) { Fabricate(:category, user: user) }
    let(:topic) { Fabricate(:topic, user: user) }
    let(:basic_topic_params) { {title: "hello world topic", raw: "my name is fred", archetype_id: 1} }
    let(:image_sizes) { {'http://an.image.host/image.jpg' => {"width" => 111, "height" => 222}} }

    let(:creator) { PostCreator.new(user, basic_topic_params) }
    let(:creator_with_category) { PostCreator.new(user, basic_topic_params.merge(category: category.id )) }
    let(:creator_with_meta_data) { PostCreator.new(user, basic_topic_params.merge(meta_data: {hello: "world"} )) }
    let(:creator_with_image_sizes) { PostCreator.new(user, basic_topic_params.merge(image_sizes: image_sizes)) }

    it "can be created with auto tracking disabled" do
      p = PostCreator.create(user, basic_topic_params.merge(auto_track: false))
      # must be 0 otherwise it will think we read the topic which is clearly untrue
      TopicUser.where(user_id: p.user_id, topic_id: p.topic_id).count.should == 0
    end

    it "ensures the user can create the topic" do
      Guardian.any_instance.expects(:can_create?).with(Topic,nil).returns(false)
      lambda { creator.create }.should raise_error(Discourse::InvalidAccess)
    end


    context "invalid title" do

      let(:creator_invalid_title) { PostCreator.new(user, basic_topic_params.merge(title: 'a')) }

      it "has errors" do
        creator_invalid_title.create
        expect(creator_invalid_title.errors).to be_present
      end

    end

    context "invalid raw" do

      let(:creator_invalid_raw) { PostCreator.new(user, basic_topic_params.merge(raw: '')) }

      it "has errors" do
        creator_invalid_raw.create
        expect(creator_invalid_raw.errors).to be_present
      end

    end

    context "success" do

      it "doesn't return true for spam" do
        creator.create
        creator.spam?.should be_false
      end

      it "does not notify on system messages" do
        admin = Fabricate(:admin)
        messages = MessageBus.track_publish do
          p = PostCreator.create(admin, basic_topic_params.merge(post_type: Post.types[:moderator_action]))
          PostCreator.create(admin, basic_topic_params.merge(topic_id: p.topic_id, post_type: Post.types[:moderator_action]))
        end
        # don't notify on system messages they introduce too much noise
        channels = messages.map(&:channel)
        channels.find{|s| s =~ /unread/}.should be_nil
        channels.find{|s| s =~ /new/}.should be_nil
      end

      it "generates the correct messages for a secure topic" do

        admin = Fabricate(:admin)

        cat = Fabricate(:category)
        cat.set_permissions(:admins => :full)
        cat.save

        created_post = nil
        reply = nil

        messages = MessageBus.track_publish do
          created_post = PostCreator.new(admin, basic_topic_params.merge(category: cat.id)).create
          reply = PostCreator.new(admin, raw: "this is my test reply 123 testing", topic_id: created_post.topic_id).create
        end


        # 2 for topic, one to notify of new topic another for tracking state
        messages.map{|m| m.channel}.sort.should == [ "/new",
                                                     "/users/#{admin.username}",
                                                     "/users/#{admin.username}",
                                                     "/unread/#{admin.id}",
                                                     "/unread/#{admin.id}",
                                                     "/topic/#{created_post.topic_id}",
                                                     "/topic/#{created_post.topic_id}"
                                                   ].sort
        admin_ids = [Group[:admins].id]

        messages.any?{|m| m.group_ids != admin_ids && m.user_ids != [admin.id]}.should be_false
      end

      it 'generates the correct messages for a normal topic' do

        p = nil
        messages = MessageBus.track_publish do
          p = creator.create
        end

        latest = messages.find{|m| m.channel == "/new"}
        latest.should_not be_nil

        read = messages.find{|m| m.channel == "/unread/#{p.user_id}"}
        read.should_not be_nil

        user_action = messages.find{|m| m.channel == "/users/#{p.user.username}"}
        user_action.should_not be_nil

        messages.length.should == 4
      end

      it 'extracts links from the post' do
        TopicLink.expects(:extract_from).with(instance_of(Post))
        creator.create
      end

      it 'queues up post processing job when saved' do
        Jobs.expects(:enqueue).with(:feature_topic_users, has_key(:topic_id))
        Jobs.expects(:enqueue).with(:process_post, has_key(:post_id))
        Jobs.expects(:enqueue).with(:notify_mailing_list_subscribers, has_key(:post_id))
        creator.create
      end

      it 'passes the invalidate_oneboxes along to the job if present' do
        Jobs.stubs(:enqueue).with(:feature_topic_users, has_key(:topic_id))
        Jobs.expects(:enqueue).with(:notify_mailing_list_subscribers, has_key(:post_id))
        Jobs.expects(:enqueue).with(:process_post, has_key(:invalidate_oneboxes))
        creator.opts[:invalidate_oneboxes] = true
        creator.create
      end

      it 'passes the image_sizes along to the job if present' do
        Jobs.stubs(:enqueue).with(:feature_topic_users, has_key(:topic_id))
        Jobs.expects(:enqueue).with(:notify_mailing_list_subscribers, has_key(:post_id))
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

        # ensure topic user is correct
        topic_user = first_post.user.topic_users.find_by(topic_id: first_post.topic_id)
        topic_user.should be_present
        topic_user.should be_posted
        topic_user.last_read_post_number.should == first_post.post_number
        topic_user.seen_post_count.should == first_post.post_number

        user2 = Fabricate(:coding_horror)
        user2.user_stat.topic_reply_count.should == 0

        first_post.user.user_stat.reload.topic_reply_count.should == 0

        PostCreator.new(user2, topic_id: first_post.topic_id, raw: "this is my test post 123").create

        first_post.user.user_stat.reload.topic_reply_count.should == 0

        user2.user_stat.reload.topic_reply_count.should == 1
      end

      it 'sets topic excerpt if first post, but not second post' do
        first_post = creator.create
        topic = first_post.topic.reload
        topic.excerpt.should be_present
        expect {
          PostCreator.new(first_post.user, topic_id: first_post.topic_id, raw: "this is the second post").create
          topic.reload
        }.to_not change { topic.excerpt }
      end
    end

    context 'when auto-close param is given' do
      it 'ensures the user can auto-close the topic, but ignores auto-close param silently' do
        Guardian.any_instance.stubs(:can_moderate?).returns(false)
        post = PostCreator.new(user, basic_topic_params.merge(auto_close_time: 2)).create
        post.topic.auto_close_at.should be_nil
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


  context "host spam" do

    let!(:topic) { Fabricate(:topic, user: user) }
    let(:basic_topic_params) { { raw: 'test reply', topic_id: topic.id, reply_to_post_number: 4} }
    let(:creator) { PostCreator.new(user, basic_topic_params) }

    before do
      Post.any_instance.expects(:has_host_spam?).returns(true)
    end

    it "does not create the post" do
      GroupMessage.stubs(:create)
      creator.create
      creator.errors.should be_present
      creator.spam?.should be_true
    end

    it "sends a message to moderators" do
      GroupMessage.expects(:create).with do |group_name, msg_type, params|
        group_name == Group[:moderators].name and msg_type == :spam_post_blocked and params[:user].id == user.id
      end
      creator.create
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

  context "cooking options" do
    let(:raw) { "this is my awesome message body hello world" }

    it "passes the cooking options through correctly" do
      creator = PostCreator.new(user,
                                title: 'hi there welcome to my topic',
                                raw: raw,
                                cooking_options: { traditional_markdown_linebreaks: true })

      Post.any_instance.expects(:cook).with(raw, has_key(:traditional_markdown_linebreaks)).returns(raw)
      creator.create
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
                               target_usernames: [target_user1.username, target_user2.username].join(','),
                               category: 1)
    end

    it 'acts correctly' do
      post.topic.archetype.should == Archetype.private_message
      post.topic.topic_allowed_users.count.should == 3

      # PMs can't have a category
      post.topic.category.should be_nil

      # does not notify an unrelated user
      unrelated.notifications.count.should == 0
      post.topic.subtype.should == TopicSubtype.user_to_user

      # if an admin replies they should be added to the allowed user list
      admin = Fabricate(:admin)
      PostCreator.create(admin, raw: 'hi there welcome topic, I am a mod',
                         topic_id: post.topic_id)

      post.topic.reload
      post.topic.topic_allowed_users.where(user_id: admin.id).count.should == 1
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

  context 'setting created_at' do
    created_at = 1.week.ago
    let(:topic) do
      PostCreator.create(user,
                         raw: 'This is very interesting test post content',
                         title: 'This is a very interesting test post title',
                         created_at: created_at)
    end

    let(:post) do
      PostCreator.create(user,
                         raw: 'This is very interesting test post content',
                         topic_id: Topic.last,
                         created_at: created_at)
    end

    it 'acts correctly' do
      topic.created_at.should be_within(10.seconds).of(created_at)
      post.created_at.should be_within(10.seconds).of(created_at)
    end
  end

  context 'disable validations' do
    it 'can save a post' do
      creator = PostCreator.new(user, raw: 'q', title: 'q', skip_validations: true)
      creator.create
      creator.errors.should be_nil
    end
  end

  describe "word_count" do
    it "has a word count" do
      creator = PostCreator.new(user, title: 'some inspired poetry for a rainy day', raw: 'mary had a little lamb, little lamb, little lamb. mary had a little lamb')
      post = creator.create
      post.word_count.should == 14

      post.topic.reload
      post.topic.word_count.should == 14
    end
  end

  describe "embed_url" do

    let(:embed_url) { "http://eviltrout.com/stupid-url" }

    it "creates the topic_embed record" do
      creator = PostCreator.new(user,
                                embed_url: embed_url,
                                title: 'Reviews of Science Ovens',
                                raw: 'Did you know that you can use microwaves to cook your dinner? Science!')
      creator.create
      TopicEmbed.where(embed_url: embed_url).exists?.should be_true
    end
  end

  describe "read credit for creator" do
    it "should give credit to creator" do
      post = create_post
      PostTiming.find_by(topic_id: post.topic_id,
                         post_number: post.post_number,
                         user_id: post.user_id).msecs.should be > 0

      TopicUser.find_by(topic_id: post.topic_id,
                        user_id: post.user_id).last_read_post_number.should == 1
    end
  end

end

