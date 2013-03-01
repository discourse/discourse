require 'spec_helper'

describe Post do

  it { should belong_to :user }
  it { should belong_to :topic }
  it { should validate_presence_of :raw }

  # Min/max body lengths, respecting padding
  it { should_not allow_value("x").for(:raw) }
  it { should_not allow_value("x" * (SiteSetting.max_post_length + 1)).for(:raw) }
  it { should_not allow_value((" " * SiteSetting.min_post_length) + "x").for(:raw) }

  it { should have_many :post_replies }
  it { should have_many :replies }

  it { should rate_limit }

  let(:topic) { Fabricate(:topic) }
  let(:post_args) do
    {user: topic.user, topic: topic}
  end

  it_behaves_like "a versioned model"

  describe 'scopes' do

    describe '#by_newest' do
      it 'returns posts ordered by created_at desc' do
        2.times { Fabricate(:post) }
        Post.by_newest.first.created_at.should > Post.by_newest.last.created_at
      end
    end

    describe '#with_user' do
      it 'gives you a user' do
        Fabricate(:post, user: Fabricate(:user))
        Post.with_user.first.user.should be_a User
      end
    end

  end

  describe 'post uniqueness' do

    context "disabled" do
      before do
        SiteSetting.stubs(:unique_posts_mins).returns(0)
        Fabricate(:post, post_args)
      end

      it "returns true for another post with the same content" do
        Fabricate.build(:post, post_args).should be_valid
      end
    end

    context 'enabled' do
      before do
        SiteSetting.stubs(:unique_posts_mins).returns(10)
        Fabricate(:post, post_args)
      end

      it "returns false for another post with the same content" do
        Fabricate.build(:post, post_args).should_not be_valid
      end

      it "returns true for admins" do
        topic.user.admin = true
        Fabricate.build(:post, post_args).should be_valid
      end

      it "returns true for moderators" do
        topic.user.trust_level = TrustLevel.levels[:moderator]
        Fabricate.build(:post, post_args).should be_valid
      end
    end

  end

  describe 'flagging helpers' do
    it 'isFlagged is accurate' do
      post = Fabricate(:post)
      user = Fabricate(:coding_horror)
      PostAction.act(user, post, PostActionType.types[:off_topic])

      post.reload
      post.is_flagged?.should == true

      PostAction.remove_act(user, post, PostActionType.types[:off_topic])
      post.reload
      post.is_flagged?.should == false
    end
  end

  describe 'message bus' do
    it 'enqueues the post on the message bus' do
      topic = self.topic
      MessageBus.expects(:publish).with("/topic/#{topic.id}", instance_of(Hash))
      Fabricate(:post, post_args)
    end
  end

  describe "maximum images" do
    let(:post_no_images) { Fabricate.build(:post, post_args) }
    let(:post_one_image) { Fabricate.build(:post, post_args.merge(raw: "![sherlock](http://bbc.co.uk/sherlock.jpg)")) }
    let(:post_two_images) { Fabricate.build(:post, post_args.merge(raw: "<img src='http://discourse.org/logo.png'> <img src='http://bbc.co.uk/sherlock.jpg'>")) }
    let(:post_with_avatars) { Fabricate.build(:post, post_args.merge(raw: '<img alt="smiley" title=":smiley:" src="/assets/emoji/smiley.png" class="avatar"> <img alt="wink" title=":wink:" src="/assets/emoji/wink.png" class="avatar">')) }
    let(:post_with_two_classy_images) { Fabricate.build(:post, post_args.merge(raw: "<img src='http://discourse.org/logo.png' class='classy'> <img src='http://bbc.co.uk/sherlock.jpg' class='classy'>")) }

    it "returns 0 images for an empty post" do
      Fabricate.build(:post).image_count.should == 0
    end

    it "finds images from markdown" do
      post_one_image.image_count.should == 1
    end

    it "finds images from HTML" do
      post_two_images.image_count.should == 2
    end

    it "doesn't count avatars as images" do
      post_with_avatars.image_count.should == 0
    end

    it "doesn't count whitelisted images" do
      Post.stubs(:white_listed_image_classes).returns(["classy"])
      post_with_two_classy_images.image_count.should == 0
    end

    context "validation" do
      it "allows a new user to make a post with one image" do
        post_no_images.user.trust_level = TrustLevel.levels[:new]
        post_no_images.should be_valid
      end

      it "doesn't allow multiple images for new accounts" do
        post_one_image.user.trust_level = TrustLevel.levels[:new]
        post_one_image.should_not be_valid
      end

      it "allows multiple images for basic accounts" do
        post_one_image.user.trust_level = TrustLevel.levels[:basic]
        post_one_image.should be_valid
      end

      it "doesn't allow a new user to edit their post to insert an image" do
        post_no_images.user.trust_level = TrustLevel.levels[:new]
        post_no_images.save
        -> {
          post_no_images.revise(post_no_images.user, post_two_images.raw)
          post_no_images.reload
        }.should_not change(post_no_images, :raw)

      end

    end

  end

  describe "maximum links" do
    let(:post_one_link) { Fabricate.build(:post, post_args.merge(raw: "[sherlock](http://www.bbc.co.uk/programmes/b018ttws)")) }
    let(:post_two_links) { Fabricate.build(:post, post_args.merge(raw: "<a href='http://discourse.org'>discourse</a> <a href='http://twitter.com'>twitter</a>")) }

    it "returns 0 images for an empty post" do
      Fabricate.build(:post).link_count.should == 0
    end

    it "finds images from markdown" do
      post_one_link.link_count.should == 1
    end

    it "finds images from HTML" do
      post_two_links.link_count.should == 2
    end

    context "validation" do
      it "allows a new user to make a post with one image" do
        post_one_link.user.trust_level = TrustLevel.levels[:new]
        post_one_link.should be_valid
      end

      it "doesn't allow multiple images for new accounts" do
        post_two_links.user.trust_level = TrustLevel.levels[:new]
        post_two_links.should_not be_valid
      end

      it "allows multiple images for basic accounts" do
        post_two_links.user.trust_level = TrustLevel.levels[:basic]
        post_two_links.should be_valid
      end
    end

  end


  describe "maximum @mentions" do

    let(:post) { Fabricate.build(:post, post_args.merge(raw: "@Jake @Finn")) }

    it "will accept a post with 2 @mentions as valid" do
      post.should be_valid
    end

    context 'raw_mentions' do

      it "returns an empty array with no matches" do
        post = Fabricate.build(:post, post_args.merge(raw: "Hello Jake and Finn!"))
        post.raw_mentions.should == []
      end

      it "returns lowercase unique versions of the mentions" do
        post = Fabricate.build(:post, post_args.merge(raw: "@Jake @Finn @Jake"))
        post.raw_mentions.should == ['jake', 'finn']
      end

      it "ignores pre" do
        post = Fabricate.build(:post, post_args.merge(raw: "<pre>@Jake</pre> @Finn"))
        post.raw_mentions.should == ['finn']
      end

      it "catches content between pre tags" do
        post = Fabricate.build(:post, post_args.merge(raw: "<pre>hello</pre> @Finn <pre></pre>"))
        post.raw_mentions.should == ['finn']
      end

      it "ignores code" do
        post = Fabricate.build(:post, post_args.merge(raw: "@Jake <code>@Finn</code>"))
        post.raw_mentions.should == ['jake']
      end

      it "ignores quotes" do
        post = Fabricate.build(:post, post_args.merge(raw: "[quote=\"Evil Trout\"]@Jake[/quote] @Finn"))
        post.raw_mentions.should == ['finn']
      end

    end

    context "With a @mention limit of 1" do
      before do
        SiteSetting.stubs(:max_mentions_per_post).returns(1)
      end

      it "wont accept the post as valid because there are too many mentions" do
        post.should_not be_valid
      end
    end

  end

  it 'validates' do
    Fabricate.build(:post, post_args).should be_valid
  end

  context "raw_hash" do

    let(:raw) { "this is our test post body"}
    let(:post) { Fabricate.build(:post, raw: raw) }

    it "returns a value" do
      post.raw_hash.should be_present
    end

    it "returns blank for a nil body" do
      post.raw = nil
      post.raw_hash.should be_blank
    end

    it "returns the same value for the same raw" do
      post.raw_hash.should == Fabricate.build(:post, raw: raw).raw_hash
    end

    it "returns a different value for a different raw" do
      post.raw_hash.should_not == Fabricate.build(:post, raw: "something else").raw_hash
    end

    it "returns the same hash even with different white space" do
      post.raw_hash.should == Fabricate.build(:post, raw: " thisis ourt est postbody").raw_hash
    end

    it "returns the same hash even with different text case" do
      post.raw_hash.should == Fabricate.build(:post, raw: "THIS is OUR TEST post BODy").raw_hash
    end
  end

  context 'revise' do

    let(:post) { Fabricate(:post, post_args) }
    let(:first_version_at) { post.last_version_at }

    it 'has one version in all_versions' do
      post.all_versions.size.should == 1
    end

    it "has an initial last_version" do
      first_version_at.should be_present
    end

    describe 'with the same body' do

      it 'returns false' do
        post.revise(post.user, post.raw).should be_false
      end

      it "doesn't change cached_version" do
        lambda { post.revise(post.user, post.raw); post.reload }.should_not change(post, :cached_version)
      end

    end

    describe 'ninja editing' do
      before do
        SiteSetting.expects(:ninja_edit_window).returns(1.minute.to_i)
        post.revise(post.user, 'updated body', revised_at: post.updated_at + 10.seconds)
        post.reload
      end

      it 'does not update cached_version' do
        post.cached_version.should == 1
      end

      it 'does not create a new version' do
        post.all_versions.size.should == 1
      end

      it "doesn't change the last_version_at" do
        post.last_version_at.should == first_version_at
      end
    end

    describe 'revision much later' do

      let!(:revised_at) { post.updated_at + 2.minutes }

      before do
        SiteSetting.stubs(:ninja_edit_window).returns(1.minute.to_i)
        post.revise(post.user, 'updated body', revised_at: revised_at)
        post.reload
      end

      it 'updates the cached_version' do
        post.cached_version.should == 2
      end

      it 'creates a new version' do
        post.all_versions.size.should == 2
      end

      it "updates the last_version_at" do
        post.last_version_at.to_i.should == revised_at.to_i
      end

      describe "new edit window" do

        before do
          post.revise(post.user, 'yet another updated body', revised_at: revised_at)
          post.reload
        end

        it "doesn't create a new version if you do another" do
          post.cached_version.should == 2
        end

        it "doesn't change last_version_at" do
          post.last_version_at.to_i.should == revised_at.to_i
        end

        context "after second window" do

          let!(:new_revised_at) {revised_at + 2.minutes}

          before do
            post.revise(post.user, 'yet another, another updated body', revised_at: new_revised_at)
            post.reload
          end

          it "does create a new version after the edit window" do
            post.cached_version.should == 3
          end

          it "does create a new version after the edit window" do
            post.last_version_at.to_i.should == new_revised_at.to_i
          end

        end


      end

    end

    describe 'rate limiter' do
      let(:changed_by) { Fabricate(:coding_horror) }

      it "triggers a rate limiter" do
        EditRateLimiter.any_instance.expects(:performed!)
        post.revise(changed_by, 'updated body')
      end
    end

    describe 'with a new body' do
      let(:changed_by) { Fabricate(:coding_horror) }
      let!(:result) { post.revise(changed_by, 'updated body') }

      it 'returns true' do
        result.should be_true
      end

      it 'updates the body' do
        post.raw.should == 'updated body'
      end

      it 'sets the invalidate oneboxes attribute' do
        post.invalidate_oneboxes.should == true
      end

      it 'increased the cached_version' do
        post.cached_version.should == 2
      end

      it 'has the new version in all_versions' do
        post.all_versions.size.should == 2
      end

      it 'has versions' do
        post.versions.should be_present
      end

      it "saved the user who made the change in the version" do
        post.versions.first.user.should be_present
      end

      context 'second poster posts again quickly' do
        before do
          SiteSetting.expects(:ninja_edit_window).returns(1.minute.to_i)
          post.revise(changed_by, 'yet another updated body', revised_at: post.updated_at + 10.seconds)
          post.reload
        end

        it 'is a ninja edit, because the second poster posted again quickly' do
          post.cached_version.should == 2
        end

        it 'is a ninja edit, because the second poster posted again quickly' do
          post.all_versions.size.should == 2
        end

      end

    end
  end

  it 'should feature users after create' do
    Jobs.stubs(:enqueue).with(:process_post, anything)
    Jobs.expects(:enqueue).with(:feature_topic_users, has_key(:topic_id))
    Fabricate(:post, post_args)
  end

  it 'should queue up a post processing job when saved' do
    Jobs.stubs(:enqueue).with(:feature_topic_users, has_key(:topic_id))
    Jobs.expects(:enqueue).with(:process_post, has_key(:post_id))
    Fabricate(:post, post_args)
  end

  it 'passes the invalidate_oneboxes along to the job if present' do
    Jobs.stubs(:enqueue).with(:feature_topic_users, has_key(:topic_id))
    Jobs.expects(:enqueue).with(:process_post, has_key(:invalidate_oneboxes))
    post = Fabricate.build(:post, post_args)
    post.invalidate_oneboxes = true
    post.save
  end

  it 'passes the image_sizes along to the job if present' do
    Jobs.stubs(:enqueue).with(:feature_topic_users, has_key(:topic_id))
    Jobs.expects(:enqueue).with(:process_post, has_key(:image_sizes))
    post = Fabricate.build(:post, post_args)
    post.image_sizes = {'http://an.image.host/image.jpg' => {'width' => 17, 'height' => 31}}
    post.save
  end

  describe 'notifications' do

    let(:coding_horror) { Fabricate(:coding_horror) }

    describe 'replies' do

      let(:post) { Fabricate(:post, post_args.merge(raw: "Hello @CodingHorror")) }

      it 'notifies the poster on reply' do
        lambda {
          @reply = Fabricate(:basic_reply, user: coding_horror, topic: post.topic)
        }.should change(post.user.notifications, :count).by(1)
      end

      it "doesn't notify the poster when they reply to their own post" do
        lambda {
          @reply = Fabricate(:basic_reply, user: post.user, topic: post.topic)
        }.should_not change(post.user.notifications, :count).by(1)
      end
    end

    describe 'watching' do
      it "does notify watching users of new posts" do
        post = Fabricate(:post, post_args)
        user2 = Fabricate(:coding_horror)
        post_args[:topic].notify_watch!(user2)
        lambda {
          Fabricate(:post, user: post.user, topic: post.topic)
        }.should change(user2.notifications, :count).by(1)
      end
    end

    describe 'muting' do
      it "does not notify users of new posts" do
        post = Fabricate(:post, post_args)
        user = post_args[:user]
        user2 = Fabricate(:coding_horror)

        post_args[:topic].notify_muted!(user)
        lambda {
          Fabricate(:post, user: user2, topic: post.topic, raw: 'hello @' + user.username)
        }.should change(user.notifications, :count).by(0)
      end
    end

  end

  describe 'delete_by' do

    let(:moderator) { Fabricate(:moderator) }
    let(:post) { Fabricate(:post) }

    context "as the creator of the post" do

      before do
        post.delete_by(post.user)
        post.reload
      end

      it "doesn't delete the post" do
        post.deleted_at.should be_blank
      end

      it "updates the text of the post" do
        post.raw.should == I18n.t('js.post.deleted_by_author')
      end


      it "creates a new version" do
        post.version.should == 2
      end

    end

    context "as a moderator" do

      before do
        post.delete_by(post.user)
        post.reload
      end

      it "deletes the post" do
        post.deleted_at.should be_blank
      end

    end

  end

  describe 'after delete' do

    let!(:coding_horror) { Fabricate(:coding_horror) }
    let!(:post) { Fabricate(:post, post_args.merge(raw: "Hello @CodingHorror")) }

    it "should feature the users again (in case they've changed)" do
      Jobs.expects(:enqueue).with(:feature_topic_users, has_entries(topic_id: post.topic_id, except_post_id: post.id))
      post.destroy
    end

    describe 'with a reply' do

      let!(:reply) { Fabricate(:basic_reply, user: coding_horror, topic: post.topic) }

      it 'changes the post count of the topic' do
        post.reload
        lambda {
          reply.destroy
          post.topic.reload
        }.should change(post.topic, :posts_count).by(-1)
      end

      it 'lowers the reply_count when the reply is deleted' do
        lambda {
          reply.destroy
          post.reload
        }.should change(post.post_replies, :count).by(-1)
      end

      it 'should increase the post_number when there are deletion gaps' do
        reply.destroy
        p = Fabricate(:post, user: post.user, topic: post.topic)
        p.post_number.should == 3
      end

    end

  end



  describe 'after save' do

    let(:post) { Fabricate(:post, post_args) }

    it "defaults to not user_deleted" do
      post.user_deleted?.should be_false
    end

    it 'has a post nubmer' do
      post.post_number.should be_present
    end

    it 'has an excerpt' do
      post.excerpt.should be_present
    end

    it 'is of the regular post type' do
      post.post_type.should == Post::REGULAR
    end

    it 'has no versions' do
      post.versions.should be_blank
    end

    it 'has cooked content' do
      post.cooked.should be_present
    end

    it 'has an external id' do
      post.external_id.should be_present
    end

    it 'has no quotes' do
      post.quote_count.should == 0
    end

    it 'has no replies' do
      post.replies.should be_blank
    end

    describe 'a forum topic user record for the topic' do

      let(:topic_user) { post.user.topic_users.where(topic_id: topic.id).first }

      it 'exists' do
        topic_user.should be_present
      end

      it 'has the posted flag set' do
        topic_user.should be_posted
      end

      it 'recorded the latest post as read' do
        topic_user.last_read_post_number.should == post.post_number
      end

      it 'recorded the latest post as the last seen' do
        topic_user.seen_post_count.should == post.post_number
      end

    end

    describe 'quote counts' do

      let!(:post) { Fabricate(:post, post_args) }
      let(:reply) { Fabricate.build(:post, post_args) }

      it "finds the quote when in the same topic" do
        reply.raw = "[quote=\"EvilTrout, post:#{post.post_number}, topic:#{post.topic_id}\"]hello[/quote]"
        reply.extract_quoted_post_numbers
        reply.quoted_post_numbers.should == [post.post_number]
      end

      it "doesn't find the quote in a different topic" do
        reply.raw = "[quote=\"EvilTrout, post:#{post.post_number}, topic:#{post.topic_id+1}\"]hello[/quote]"
        reply.extract_quoted_post_numbers
        reply.quoted_post_numbers.should be_blank
      end

    end

    describe 'a new reply' do

      let!(:post) { Fabricate(:post, post_args) }
      let!(:reply) { Fabricate(:reply, post_args.merge(reply_to_post_number: post.post_number)) }

      it 'has a quote' do
        reply.quote_count.should == 1
      end

      it "isn't quoteless" do
        reply.should_not be_quoteless
      end

      it 'has a reply to the user of the original user' do
        reply.reply_to_user.should == post.user
      end

      it 'increases the reply count of the parent' do
        post.reload
        post.reply_count.should == 1
      end

      it 'increases the reply count of the topic' do
        topic.reload
        topic.reply_count.should == 1
      end

      it 'is the child of the parent post' do
        post.replies.should == [reply]
      end


      it "doesn't change the post count when you edit the reply" do
        reply.raw = 'updated raw'
        reply.save
        post.reload
        post.reply_count.should == 1
      end

      context 'a multi-quote reply' do

        let!(:multi_reply) { Fabricate(:multi_quote_reply, post_args.merge(reply_to_post_number: post.post_number)) }

        it 'has two quotes' do
          multi_reply.quote_count.should == 2
        end

        it 'is a child of the parent post' do
          post.replies.include?(multi_reply).should be_true
        end

        it 'is a child of the second post quoted' do
          reply.replies.include?(multi_reply).should be_true
        end

      end

    end

  end

  context 'best_of' do
    let!(:p1) { Fabricate(:post, post_args.merge(score: 4)) }
    let!(:p2) { Fabricate(:post, post_args.merge(score: 10)) }
    let!(:p3) { Fabricate(:post, post_args.merge(score: 5)) }

    it "returns the OP and posts above the threshold in best of mode" do
      SiteSetting.stubs(:best_of_score_threshold).returns(10)
      Post.best_of.order(:post_number).should == [p1, p2]
    end

  end


  context 'sort_order' do

    context 'regular topic' do

      let!(:p1) { Fabricate(:post, post_args) }
      let!(:p2) { Fabricate(:post, post_args) }
      let!(:p3) { Fabricate(:post, post_args) }

      it 'defaults to created order' do
        Post.regular_order.should == [p1, p2, p3]
      end
    end

  end

  describe '#readable_author' do
    it 'delegates to the associated user' do
      User.any_instance.expects(:readable_name)
      Fabricate(:post).author_readable
    end
  end

end
