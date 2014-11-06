require 'spec_helper'
require_dependency 'post_destroyer'

describe Post do
  before { Oneboxer.stubs :onebox }

  # Help us build a post with a raw body
  def post_with_body(body, user=nil)
    args = post_args.merge(raw: body)
    args[:user] = user if user.present?
    Fabricate.build(:post, args)
  end

  it { should validate_presence_of :raw }

  # Min/max body lengths, respecting padding
  it { should_not allow_value("x").for(:raw) }
  it { should_not allow_value("x" * (SiteSetting.max_post_length + 1)).for(:raw) }
  it { should_not allow_value((" " * SiteSetting.min_post_length) + "x").for(:raw) }

  it { should rate_limit }

  let(:topic) { Fabricate(:topic) }
  let(:post_args) do
    { user: topic.user, topic: topic }
  end

  describe 'scopes' do

    describe '#by_newest' do
      it 'returns posts ordered by created_at desc' do
        2.times do |t|
          Fabricate(:post, created_at: t.seconds.from_now)
        end
        Post.by_newest.first.created_at.should > Post.by_newest.last.created_at
      end
    end

    describe '#with_user' do
      it 'gives you a user' do
        Fabricate(:post, user: Fabricate.build(:user))
        Post.with_user.first.user.should be_a User
      end
    end

  end

  describe "revisions and deleting/recovery" do

    context 'a post without links' do
      let(:post) { Fabricate(:post, post_args) }

      before do
        post.trash!
        post.reload
      end

      it "doesn't create a new revision when deleted" do
        post.revisions.count.should == 0
      end

      describe "recovery" do
        before do
          post.recover!
          post.reload
        end

        it "doesn't create a new revision when recovered" do
          post.revisions.count.should == 0
        end
      end
    end

    context 'a post with links' do
      let(:post) { Fabricate(:post_with_external_links) }
      before do
        post.trash!
        post.reload
      end

      describe 'recovery' do
        it 'recreates the topic_link records' do
          TopicLink.expects(:extract_from).with(post)
          post.recover!
        end
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

  describe "maximum images" do
    let(:newuser) { Fabricate(:user, trust_level: TrustLevel[0]) }
    let(:post_no_images) { Fabricate.build(:post, post_args.merge(user: newuser)) }
    let(:post_one_image) { post_with_body("![sherlock](http://bbc.co.uk/sherlock.jpg)", newuser) }
    let(:post_two_images) { post_with_body("<img src='http://discourse.org/logo.png'> <img src='http://bbc.co.uk/sherlock.jpg'>", newuser) }
    let(:post_with_avatars) { post_with_body('<img alt="smiley" title=":smiley:" src="/assets/emoji/smiley.png" class="avatar"> <img alt="wink" title=":wink:" src="/assets/emoji/wink.png" class="avatar">', newuser) }
    let(:post_with_favicon) { post_with_body('<img src="/assets/favicons/wikipedia.png" class="favicon">', newuser) }
    let(:post_with_thumbnail) { post_with_body('<img src="/assets/emoji/smiley.png" class="thumbnail">', newuser) }
    let(:post_with_two_classy_images) { post_with_body("<img src='http://discourse.org/logo.png' class='classy'> <img src='http://bbc.co.uk/sherlock.jpg' class='classy'>", newuser) }

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

    it "doesn't count favicons as images" do
      post_with_favicon.image_count.should == 0
    end

    it "doesn't count thumbnails as images" do
      post_with_thumbnail.image_count.should == 0
    end

    it "doesn't count whitelisted images" do
      Post.stubs(:white_listed_image_classes).returns(["classy"])
      post_with_two_classy_images.image_count.should == 0
    end

    context "validation" do

      before do
        SiteSetting.stubs(:newuser_max_images).returns(1)
      end

      context 'newuser' do
        it "allows a new user to post below the limit" do
          post_one_image.should be_valid
        end

        it "doesn't allow more than the maximum" do
          post_two_images.should_not be_valid
        end

        it "doesn't allow a new user to edit their post to insert an image" do
          post_no_images.user.trust_level = TrustLevel[0]
          post_no_images.save
          -> {
            post_no_images.revise(post_no_images.user, { raw: post_two_images.raw })
            post_no_images.reload
          }.should_not change(post_no_images, :raw)
        end
      end

      it "allows more images from a not-new account" do
        post_two_images.user.trust_level = TrustLevel[1]
        post_two_images.should be_valid
      end

    end

  end

  describe "maximum attachments" do
    let(:newuser) { Fabricate(:user, trust_level: TrustLevel[0]) }
    let(:post_no_attachments) { Fabricate.build(:post, post_args.merge(user: newuser)) }
    let(:post_one_attachment) { post_with_body('<a class="attachment" href="/uploads/default/1/2082985.txt">file.txt</a>', newuser) }
    let(:post_two_attachments) { post_with_body('<a class="attachment" href="/uploads/default/2/20947092.log">errors.log</a> <a class="attachment" href="/uploads/default/3/283572385.3ds">model.3ds</a>', newuser) }

    it "returns 0 attachments for an empty post" do
      Fabricate.build(:post).attachment_count.should == 0
    end

    it "finds attachments from HTML" do
      post_two_attachments.attachment_count.should == 2
    end

    context "validation" do

      before do
        SiteSetting.stubs(:newuser_max_attachments).returns(1)
      end

      context 'newuser' do
        it "allows a new user to post below the limit" do
          post_one_attachment.should be_valid
        end

        it "doesn't allow more than the maximum" do
          post_two_attachments.should_not be_valid
        end

        it "doesn't allow a new user to edit their post to insert an attachment" do
          post_no_attachments.user.trust_level = TrustLevel[0]
          post_no_attachments.save
          -> {
            post_no_attachments.revise(post_no_attachments.user, { raw: post_two_attachments.raw })
            post_no_attachments.reload
          }.should_not change(post_no_attachments, :raw)
        end
      end

      it "allows more attachments from a not-new account" do
        post_two_attachments.user.trust_level = TrustLevel[1]
        post_two_attachments.should be_valid
      end

    end

  end

  context "links" do
    let(:newuser) { Fabricate(:user, trust_level: TrustLevel[0]) }
    let(:no_links) { post_with_body("hello world my name is evil trout", newuser) }
    let(:one_link) { post_with_body("[jlawr](http://www.imdb.com/name/nm2225369)", newuser) }
    let(:two_links) { post_with_body("<a href='http://disneyland.disney.go.com/'>disney</a> <a href='http://reddit.com'>reddit</a>", newuser)}
    let(:three_links) { post_with_body("http://discourse.org and http://discourse.org/another_url and http://www.imdb.com/name/nm2225369", newuser)}

    describe "raw_links" do
      it "returns a blank collection for a post with no links" do
        no_links.raw_links.should be_blank
      end

      it "finds a link within markdown" do
        one_link.raw_links.should == ["http://www.imdb.com/name/nm2225369"]
      end

      it "can find two links from html" do
        two_links.raw_links.should == ["http://disneyland.disney.go.com/", "http://reddit.com"]
      end

      it "can find three links without markup" do
        three_links.raw_links.should == ["http://discourse.org", "http://discourse.org/another_url", "http://www.imdb.com/name/nm2225369"]
      end
    end

    describe "linked_hosts" do
      it "returns blank with no links" do
        no_links.linked_hosts.should be_blank
      end

      it "returns the host and a count for links" do
        two_links.linked_hosts.should == {"disneyland.disney.go.com" => 1, "reddit.com" => 1}
      end

      it "it counts properly with more than one link on the same host" do
        three_links.linked_hosts.should == {"discourse.org" => 1, "www.imdb.com" => 1}
      end
    end

    describe "total host usage" do

      it "has none for a regular post" do
        no_links.total_hosts_usage.should be_blank
      end

      context "with a previous host" do

        let(:user) { old_post.newuser }
        let(:another_disney_link) { post_with_body("[radiator springs](http://disneyland.disney.go.com/disney-california-adventure/radiator-springs-racers/)", newuser) }

        before do
          another_disney_link.save
          TopicLink.extract_from(another_disney_link)
        end

        it "contains the new post's links, PLUS the previous one" do
          two_links.total_hosts_usage.should == {'disneyland.disney.go.com' => 2, 'reddit.com' => 1}
        end

      end

    end


  end


  describe "maximum links" do
    let(:newuser) { Fabricate(:user, trust_level: TrustLevel[0]) }
    let(:post_one_link) { post_with_body("[sherlock](http://www.bbc.co.uk/programmes/b018ttws)", newuser) }
    let(:post_two_links) { post_with_body("<a href='http://discourse.org'>discourse</a> <a href='http://twitter.com'>twitter</a>", newuser) }
    let(:post_with_mentions) { post_with_body("hello @#{newuser.username} how are you doing?", newuser) }

    it "returns 0 links for an empty post" do
      Fabricate.build(:post).link_count.should == 0
    end

    it "returns 0 links for a post with mentions" do
      post_with_mentions.link_count.should == 0
    end

    it "finds links from markdown" do
      post_one_link.link_count.should == 1
    end

    it "finds links from HTML" do
      post_two_links.link_count.should == 2
    end

    context "validation" do

      before do
        SiteSetting.stubs(:newuser_max_links).returns(1)
      end

      context 'newuser' do
        it "returns true when within the amount of links allowed" do
          post_one_link.should be_valid
        end

        it "doesn't allow more links than allowed" do
          post_two_links.should_not be_valid
        end
      end

      it "allows multiple images for basic accounts" do
        post_two_links.user.trust_level = TrustLevel[1]
        post_two_links.should be_valid
      end

    end

  end


  describe "@mentions" do

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
        post = Fabricate.build(:post, post_args.merge(raw: "@Jake `@Finn`"))
        post.raw_mentions.should == ['jake']
      end

      it "ignores quotes" do
        post = Fabricate.build(:post, post_args.merge(raw: "[quote=\"Evil Trout\"]@Jake[/quote] @Finn"))
        post.raw_mentions.should == ['finn']
      end

      it "handles underscore in username" do
        post = Fabricate.build(:post, post_args.merge(raw: "@Jake @Finn @Jake_Old"))
        post.raw_mentions.should == ['jake', 'finn', 'jake_old']
      end

    end

    context "max mentions" do

      let(:newuser) { Fabricate(:user, trust_level: TrustLevel[0]) }
      let(:post_with_one_mention) { post_with_body("@Jake is the person I'm mentioning", newuser) }
      let(:post_with_two_mentions) { post_with_body("@Jake @Finn are the people I'm mentioning", newuser) }

      context 'new user' do
        before do
          SiteSetting.stubs(:newuser_max_mentions_per_post).returns(1)
          SiteSetting.stubs(:max_mentions_per_post).returns(5)
        end

        it "allows a new user to have newuser_max_mentions_per_post mentions" do
          post_with_one_mention.should be_valid
        end

        it "doesn't allow a new user to have more than newuser_max_mentions_per_post mentions" do
          post_with_two_mentions.should_not be_valid
        end
      end

      context "not a new user" do
        before do
          SiteSetting.stubs(:newuser_max_mentions_per_post).returns(0)
          SiteSetting.stubs(:max_mentions_per_post).returns(1)
        end

        it "allows vmax_mentions_per_post mentions" do
          post_with_one_mention.user.trust_level = TrustLevel[1]
          post_with_one_mention.should be_valid
        end

        it "doesn't allow to have more than max_mentions_per_post mentions" do
          post_with_two_mentions.user.trust_level = TrustLevel[1]
          post_with_two_mentions.should_not be_valid
        end
      end


    end

  end

  context 'validation' do
    it 'validates our default post' do
      Fabricate.build(:post, post_args).should be_valid
    end

    it 'treate blank posts as invalid' do
      Fabricate.build(:post, raw: "").should_not be_valid
    end
  end

  context "raw_hash" do

    let(:raw) { "this is our test post body"}
    let(:post) { post_with_body(raw) }

    it "returns a value" do
      post.raw_hash.should be_present
    end

    it "returns blank for a nil body" do
      post.raw = nil
      post.raw_hash.should be_blank
    end

    it "returns the same value for the same raw" do
      post.raw_hash.should == post_with_body(raw).raw_hash
    end

    it "returns a different value for a different raw" do
      post.raw_hash.should_not == post_with_body("something else").raw_hash
    end

    it "returns a different value with different text case" do
      post.raw_hash.should_not == post_with_body("THIS is OUR TEST post BODy").raw_hash
    end
  end

  context 'revise' do

    let(:post) { Fabricate(:post, post_args) }
    let(:first_version_at) { post.last_version_at }

    it 'has no revision' do
      post.revisions.size.should == 0
      first_version_at.should be_present
      post.revise(post.user, { raw: post.raw }).should == false
    end

    describe 'with the same body' do

      it "doesn't change version" do
        lambda { post.revise(post.user, { raw: post.raw }); post.reload }.should_not change(post, :version)
      end

    end

    describe 'ninja editing & edit windows' do

      before { SiteSetting.stubs(:ninja_edit_window).returns(1.minute.to_i) }

      it 'works' do
        revised_at = post.updated_at + 2.minutes
        new_revised_at = revised_at + 2.minutes

        # ninja edit
        post.revise(post.user, { raw: 'updated body' }, revised_at: post.updated_at + 10.seconds)
        post.reload
        post.version.should == 1
        post.public_version.should == 1
        post.revisions.size.should == 0
        post.last_version_at.to_i.should == first_version_at.to_i

        # revision much later
        post.revise(post.user, { raw: 'another updated body' }, revised_at: revised_at)
        post.reload
        post.version.should == 2
        post.public_version.should == 2
        post.revisions.size.should == 1
        post.last_version_at.to_i.should == revised_at.to_i

        # new edit window
        post.revise(post.user, { raw: 'yet another updated body' }, revised_at: revised_at + 10.seconds)
        post.reload
        post.version.should == 2
        post.public_version.should == 2
        post.revisions.size.should == 1
        post.last_version_at.to_i.should == revised_at.to_i

        # after second window
        post.revise(post.user, { raw: 'yet another, another updated body' }, revised_at: new_revised_at)
        post.reload
        post.version.should == 3
        post.public_version.should == 3
        post.revisions.size.should == 2
        post.last_version_at.to_i.should == new_revised_at.to_i
      end

    end

    describe 'rate limiter' do
      let(:changed_by) { Fabricate(:coding_horror) }

      it "triggers a rate limiter" do
        EditRateLimiter.any_instance.expects(:performed!)
        post.revise(changed_by, { raw: 'updated body' })
      end
    end

    describe 'with a new body' do
      let(:changed_by) { Fabricate(:coding_horror) }
      let!(:result) { post.revise(changed_by, { raw: 'updated body' }) }

      it 'acts correctly' do
        result.should == true
        post.raw.should == 'updated body'
        post.invalidate_oneboxes.should == true
        post.version.should == 2
        post.public_version.should == 2
        post.revisions.size.should == 1
        post.revisions.first.user.should be_present
      end

      context 'second poster posts again quickly' do

        it 'is a ninja edit, because the second poster posted again quickly' do
          SiteSetting.expects(:ninja_edit_window).returns(1.minute.to_i)
          post.revise(changed_by, { raw: 'yet another updated body' }, revised_at: post.updated_at + 10.seconds)
          post.reload

          post.version.should == 2
          post.public_version.should == 2
          post.revisions.size.should == 1
        end

      end

    end

  end


  describe 'after save' do

    let(:post) { Fabricate(:post, post_args) }

    it "has correct info set" do
      post.user_deleted?.should == false
      post.post_number.should be_present
      post.excerpt.should be_present
      post.post_type.should == Post.types[:regular]
      post.revisions.should be_blank
      post.cooked.should be_present
      post.external_id.should be_present
      post.quote_count.should == 0
      post.replies.should be_blank
    end

    describe 'extract_quoted_post_numbers' do

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

      let(:topic) { Fabricate(:topic) }
      let(:other_user) { Fabricate(:coding_horror) }
      let(:reply_text) { "[quote=\"Evil Trout, post:1\"]\nhello\n[/quote]\nHmmm!"}
      let!(:post) { PostCreator.new(topic.user, raw: Fabricate.build(:post).raw, topic_id: topic.id).create }
      let!(:reply) { PostCreator.new(other_user, raw: reply_text, topic_id: topic.id, reply_to_post_number: post.post_number ).create }

      it 'has a quote' do
        reply.quote_count.should == 1
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

        let!(:multi_reply) do
          raw = "[quote=\"Evil Trout, post:1\"]post1 quote[/quote]\nAha!\n[quote=\"Evil Trout, post:2\"]post2 quote[/quote]\nNeat-o"
          PostCreator.new(other_user, raw: raw, topic_id: topic.id, reply_to_post_number: post.post_number).create
        end

        it 'has the correct info set' do
          multi_reply.quote_count.should == 2
          post.replies.include?(multi_reply).should == true
          reply.replies.include?(multi_reply).should == true
        end
      end

    end

  end

  context 'summary' do
    let!(:p1) { Fabricate(:post, post_args.merge(score: 4, percent_rank: 0.33)) }
    let!(:p2) { Fabricate(:post, post_args.merge(score: 10, percent_rank: 0.66)) }
    let!(:p3) { Fabricate(:post, post_args.merge(score: 5, percent_rank: 0.99)) }

    it "returns the OP and posts above the threshold in summary mode" do
      SiteSetting.stubs(:summary_percent_filter).returns(66)
      Post.summary.order(:post_number).should == [p1, p2]
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

  context "reply_history" do

    let!(:p1) { Fabricate(:post, post_args) }
    let!(:p2) { Fabricate(:post, post_args.merge(reply_to_post_number: p1.post_number)) }
    let!(:p3) { Fabricate(:post, post_args) }
    let!(:p4) { Fabricate(:post, post_args.merge(reply_to_post_number: p2.post_number)) }

    it "returns the posts in reply to this post" do
      p4.reply_history.should == [p1, p2]
      p4.reply_history(1).should == [p2]
      p3.reply_history.should be_blank
      p2.reply_history.should == [p1]
    end

  end

  describe 'urls' do
    it 'no-ops for empty list' do
      Post.urls([]).should == {}
    end

    # integration test -> should move to centralized integration test
    it 'finds urls for posts presented' do
      p1 = Fabricate(:post)
      p2 = Fabricate(:post)
      Post.urls([p1.id, p2.id]).should == {p1.id => p1.url, p2.id => p2.url}
    end
  end

  describe "details" do
    it "adds details" do
      post = Fabricate.build(:post)
      post.add_detail("key", "value")
      post.post_details.size.should == 1
      post.post_details.first.key.should == "key"
      post.post_details.first.value.should == "value"
    end

    it "can find a post by a detail" do
      detail = Fabricate(:post_detail)
      post   = detail.post
      Post.find_by_detail(detail.key, detail.value).id.should == post.id
    end
  end

  describe "cooking" do
    let(:post) { Fabricate.build(:post, post_args.merge(raw: "please read my blog http://blog.example.com")) }

    it "should add nofollow to links in the post for trust levels below 3" do
      post.user.trust_level = 2
      post.save
      post.cooked.should =~ /nofollow/
    end

    it "when tl3_links_no_follow is false, should not add nofollow for trust level 3 and higher" do
      SiteSetting.stubs(:tl3_links_no_follow).returns(false)
      post.user.trust_level = 3
      post.save
      post.cooked.should_not =~ /nofollow/
    end

    it "when tl3_links_no_follow is true, should add nofollow for trust level 3 and higher" do
      SiteSetting.stubs(:tl3_links_no_follow).returns(true)
      post.user.trust_level = 3
      post.save
      post.cooked.should =~ /nofollow/
    end
  end

  describe "calculate_avg_time" do

    it "should not crash" do
      Post.calculate_avg_time
      Post.calculate_avg_time(1.day.ago)
    end
  end


  describe "has_host_spam" do
    it "correctly detects host spam" do
      post = Fabricate(:post, raw: "hello from my site http://www.somesite.com http://#{GlobalSetting.hostname} http://#{RailsMultisite::ConnectionManagement.current_hostname}")

      post.total_hosts_usage.should == {"www.somesite.com" => 1}
      post.acting_user.trust_level = 0

      post.has_host_spam?.should == false

      SiteSetting.newuser_spam_host_threshold = 1

      post.has_host_spam?.should == true

      SiteSetting.white_listed_spam_host_domains = "bla.com|boo.com | somesite.com "
      post.has_host_spam?.should == false
    end
  end

  it "has custom fields" do
    post = Fabricate(:post)
    post.custom_fields["a"].should == nil

    post.custom_fields["Tommy"] = "Hanks"
    post.custom_fields["Vincent"] = "Vega"
    post.save

    post = Post.find(post.id)
    post.custom_fields.should == {"Tommy" => "Hanks", "Vincent" => "Vega"}
  end

  describe "#rebake!" do
    it "will rebake a post correctly" do
      post = create_post
      post.baked_at.should_not == nil
      first_baked = post.baked_at
      first_cooked = post.cooked

      Post.exec_sql("UPDATE posts SET cooked = 'frogs' WHERE id = ?", post.id)
      post.reload

      post.expects(:publish_change_to_clients!).with(:rebaked)

      result = post.rebake!

      post.baked_at.should_not == first_baked
      post.cooked.should == first_cooked
      result.should == true
    end
  end

  describe ".rebake_old" do
    it "will catch posts it needs to rebake" do
      post = create_post
      post.update_columns(baked_at: Time.new(2000,1,1), baked_version: -1)
      Post.rebake_old(100)

      post.reload
      post.baked_at.should be > 1.day.ago

      baked = post.baked_at
      Post.rebake_old(100)
      post.reload
      post.baked_at.should == baked
    end
  end

  describe ".unhide!" do
    before { SiteSetting.stubs(:unique_posts_mins).returns(5) }

    it "will unhide the post" do
      post = create_post(user: Fabricate(:newuser))
      post.update_columns(hidden: true, hidden_at: Time.now, hidden_reason_id: 1)
      post.reload

      post.hidden.should == true

      post.expects(:publish_change_to_clients!).with(:acted)

      post.unhide!
      post.reload

      post.hidden.should == false
    end
  end

end
