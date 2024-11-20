# frozen_string_literal: true

RSpec.describe Post do
  fab!(:coding_horror) { Fabricate(:coding_horror, refresh_auto_groups: true) }

  let(:upload_path) { Discourse.store.upload_path }

  before { Oneboxer.stubs :onebox }

  it_behaves_like "it has custom fields"

  it { is_expected.to have_many(:reviewables).dependent(:destroy) }

  describe "#hidden_reasons" do
    context "when verifying enum sequence" do
      before { @hidden_reasons = Post.hidden_reasons }

      it "'flag_threshold_reached' should be at 1st position" do
        expect(@hidden_reasons[:flag_threshold_reached]).to eq(1)
      end

      it "'flagged_by_tl3_user' should be at 4th position" do
        expect(@hidden_reasons[:flagged_by_tl3_user]).to eq(4)
      end
    end
  end

  describe "#types" do
    context "when verifying enum sequence" do
      before { @types = Post.types }

      it "'regular' should be at 1st position" do
        expect(@types[:regular]).to eq(1)
      end

      it "'whisper' should be at 4th position" do
        expect(@types[:whisper]).to eq(4)
      end
    end
  end

  describe "#cook_methods" do
    context "when verifying enum sequence" do
      before { @cook_methods = Post.cook_methods }

      it "'regular' should be at 1st position" do
        expect(@cook_methods[:regular]).to eq(1)
      end

      it "'email' should be at 3rd position" do
        expect(@cook_methods[:email]).to eq(3)
      end
    end
  end

  # Help us build a post with a raw body
  def post_with_body(body, user = nil)
    args = post_args.merge(raw: body)
    args[:user] = user if user.present?
    Fabricate.build(:post, args)
  end

  it { is_expected.to validate_presence_of :raw }
  it { is_expected.to validate_length_of(:edit_reason).is_at_most(1000) }

  # Min/max body lengths, respecting padding
  it { is_expected.not_to allow_value("x").for(:raw) }
  it { is_expected.not_to allow_value("x" * (SiteSetting.max_post_length + 1)).for(:raw) }
  it { is_expected.not_to allow_value((" " * SiteSetting.min_post_length) + "x").for(:raw) }

  it { is_expected.to rate_limit }

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:topic) { Fabricate(:topic, user: user) }
  let(:post_args) { { user: topic.user, topic: topic } }

  describe "scopes" do
    describe "#by_newest" do
      it "returns posts ordered by created_at desc" do
        2.times { |t| Fabricate(:post, created_at: t.seconds.from_now) }
        expect(Post.by_newest.first.created_at).to be > Post.by_newest.last.created_at
      end
    end

    describe "#with_user" do
      it "gives you a user" do
        Fabricate(:post, user: Fabricate.build(:user))
        expect(Post.with_user.first.user).to be_a User
      end
    end
  end

  describe "revisions and deleting/recovery" do
    context "with a post without links" do
      let(:post) { Fabricate(:post, post_args) }

      before do
        post.trash!
        post.reload
      end

      it "doesn't create a new revision when deleted" do
        expect(post.revisions.count).to eq(0)
      end

      describe "recovery" do
        before do
          post.recover!
          post.reload
        end

        it "doesn't create a new revision when recovered" do
          expect(post.revisions.count).to eq(0)
        end
      end
    end

    context "with a post with links" do
      let(:post) { Fabricate(:post_with_external_links) }
      before do
        post.trash!
        post.reload
      end

      describe "recovery" do
        it "recreates the topic_link records" do
          TopicLink.expects(:extract_from).with(post)
          post.recover!
        end
      end
    end
  end

  context "with a post with notices" do
    let(:post) do
      post = Fabricate(:post, post_args)
      post.upsert_custom_fields(
        Post::NOTICE => {
          type: Post.notices[:returning_user],
          last_posted_at: 1.day.ago,
        },
      )
      post
    end

    it "will have its notice cleared when post is trashed" do
      expect { post.trash! }.to change { post.custom_fields }.to({})
    end
  end

  describe "should_secure_uploads?" do
    let(:topic) { Fabricate(:topic) }
    let!(:post) { Fabricate(:post, topic: topic) }

    it "returns false if secure uploads is not enabled" do
      expect(post.should_secure_uploads?).to eq(false)
    end

    context "when secure uploads is enabled" do
      before do
        setup_s3
        SiteSetting.authorized_extensions = "pdf|png|jpg|csv"
        SiteSetting.secure_uploads = true
      end

      context "if login_required" do
        before { SiteSetting.login_required = true }

        it "returns true" do
          expect(post.should_secure_uploads?).to eq(true)
        end

        context "if secure_uploads_pm_only" do
          before { SiteSetting.secure_uploads_pm_only = true }

          it "returns false" do
            expect(post.should_secure_uploads?).to eq(false)
          end
        end
      end

      context "if the topic category is read_restricted" do
        let(:category) { Fabricate(:private_category, group: Fabricate(:group)) }
        before { topic.change_category_to_id(category.id) }

        it "returns true" do
          expect(post.should_secure_uploads?).to eq(true)
        end

        context "when the topic is deleted" do
          before do
            topic.trash!
            post.reload
          end

          it "returns true" do
            expect(post.should_secure_uploads?).to eq(true)
          end
        end

        context "if secure_uploads_pm_only" do
          before { SiteSetting.secure_uploads_pm_only = true }

          it "returns false" do
            expect(post.should_secure_uploads?).to eq(false)
          end
        end
      end

      context "if the post is in a PM topic" do
        let(:topic) { Fabricate(:private_message_topic) }

        it "returns true" do
          expect(post.should_secure_uploads?).to eq(true)
        end

        context "when the topic is deleted" do
          before { topic.trash! }

          it "returns true" do
            expect(post.should_secure_uploads?).to eq(true)
          end
        end

        context "if secure_uploads_pm_only" do
          before { SiteSetting.secure_uploads_pm_only = true }

          it "returns true" do
            expect(post.should_secure_uploads?).to eq(true)
          end
        end
      end
    end
  end

  describe "flagging helpers" do
    fab!(:post)
    fab!(:user) { coding_horror }
    fab!(:admin)

    it "is_flagged? is accurate" do
      PostActionCreator.off_topic(user, post)
      expect(post.reload.is_flagged?).to eq(true)

      PostActionDestroyer.destroy(user, post, :off_topic)
      expect(post.reload.is_flagged?).to eq(false)
    end

    it "is_flagged? is true if flag was deferred" do
      result = PostActionCreator.off_topic(user, post)
      result.reviewable.perform(admin, :ignore_and_do_nothing)
      expect(post.reload.is_flagged?).to eq(true)
    end

    it "is_flagged? is true if flag was cleared" do
      result = PostActionCreator.off_topic(user, post)
      result.reviewable.perform(admin, :disagree)
      expect(post.reload.is_flagged?).to eq(true)
    end

    it "reviewable_flag is nil when ignored" do
      result = PostActionCreator.spam(user, post)
      expect(post.reviewable_flag).to eq(result.reviewable)

      result.reviewable.perform(admin, :ignore_and_do_nothing)
      expect(post.reviewable_flag).to be_nil
    end

    it "reviewable_flag is nil when disagreed" do
      result = PostActionCreator.spam(user, post)
      expect(post.reviewable_flag).to eq(result.reviewable)

      result.reviewable.perform(admin, :disagree)
      expect(post.reload.reviewable_flag).to be_nil
    end
  end

  describe "maximum media embeds" do
    fab!(:newuser) { Fabricate(:user, trust_level: TrustLevel[0]) }
    let(:post_no_images) { Fabricate.build(:post, post_args.merge(user: newuser)) }
    let(:post_one_image) { post_with_body("![sherlock](http://bbc.co.uk/sherlock.jpg)", newuser) }
    let(:post_two_images) do
      post_with_body(
        "<img src='http://discourse.org/logo.png'> <img src='http://bbc.co.uk/sherlock.jpg'>",
        newuser,
      )
    end
    let(:post_with_avatars) do
      post_with_body(
        '<img alt="smiley" title=":smiley:" src="/assets/emoji/smiley.png" class="avatar"> <img alt="wink" title=":wink:" src="/assets/emoji/wink.png" class="avatar">',
        newuser,
      )
    end
    let(:post_with_favicon) do
      post_with_body('<img src="/images/favicons/discourse.png" class="favicon">', newuser)
    end
    let(:post_image_within_quote) do
      post_with_body('[quote]<img src="coolimage.png">[/quote]', newuser)
    end
    let(:post_image_within_code) do
      post_with_body('<code><img src="coolimage.png"></code>', newuser)
    end
    let(:post_image_within_pre) { post_with_body('<pre><img src="coolimage.png"></pre>', newuser) }
    let(:post_with_thumbnail) do
      post_with_body('<img src="/assets/emoji/smiley.png" class="thumbnail">', newuser)
    end
    let(:post_with_two_classy_images) do
      post_with_body(
        "<img src='http://discourse.org/logo.png' class='classy'> <img src='http://bbc.co.uk/sherlock.jpg' class='classy'>",
        newuser,
      )
    end
    let(:post_with_two_embedded_media) do
      post_with_body(
        '<video width="950" height="700" controls><source src="https://bbc.co.uk/news.mp4" type="video/mp4"></video><audio controls><source type="audio/mpeg" src="https://example.com/audio.mp3"></audio>',
        newuser,
      )
    end

    it "returns 0 images for an empty post" do
      expect(Fabricate.build(:post).embedded_media_count).to eq(0)
    end

    it "finds images from markdown" do
      expect(post_one_image.embedded_media_count).to eq(1)
    end

    it "finds images from HTML" do
      expect(post_two_images.embedded_media_count).to eq(2)
    end

    it "doesn't count avatars as images" do
      expect(post_with_avatars.embedded_media_count).to eq(0)
    end

    it "allows images by default" do
      expect(post_one_image).to be_valid
    end

    it "doesn't count favicons as images" do
      PrettyText.stubs(:cook).returns(post_with_favicon.raw)
      expect(post_with_favicon.embedded_media_count).to eq(0)
    end

    it "doesn't count thumbnails as images" do
      PrettyText.stubs(:cook).returns(post_with_thumbnail.raw)
      expect(post_with_thumbnail.embedded_media_count).to eq(0)
    end

    it "doesn't count allowlisted images" do
      Post.stubs(:allowed_image_classes).returns(["classy"])
      # I dislike this, but passing in a custom allowlist is hard
      PrettyText.stubs(:cook).returns(post_with_two_classy_images.raw)
      expect(post_with_two_classy_images.embedded_media_count).to eq(0)
    end

    it "counts video and audio as embedded media" do
      expect(post_with_two_embedded_media.embedded_media_count).to eq(2)
    end

    describe "embedded_media_allowed_groups" do
      it "doesn't allow users outside of `embedded_media_post_allowed_groups`" do
        SiteSetting.embedded_media_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
        post_one_image.user.change_trust_level!(3)
        expect(post_one_image).not_to be_valid
      end

      it "doesn't allow users outside of `embedded_media_post_allowed_groups` in a quote" do
        SiteSetting.embedded_media_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
        post_one_image.user.change_trust_level!(3)
        expect(post_image_within_quote).not_to be_valid
      end

      it "doesn't allow users outside of `embedded_media_post_allowed_groups` in code" do
        SiteSetting.embedded_media_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
        post_one_image.user.change_trust_level!(3)
        expect(post_image_within_code).not_to be_valid
      end

      it "doesn't allow users outside of `embedded_media_post_allowed_groups` in pre" do
        SiteSetting.embedded_media_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
        post_one_image.user.change_trust_level!(3)
        expect(post_image_within_pre).not_to be_valid
      end

      it "allows users who are in a group in `embedded_media_post_allowed_groups`" do
        SiteSetting.embedded_media_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_4]
        post_one_image.user.change_trust_level!(4)
        expect(post_one_image).to be_valid
      end
    end

    context "with validation" do
      before { SiteSetting.newuser_max_embedded_media = 1 }

      context "with newuser" do
        it "allows a new user to post below the limit" do
          expect(post_one_image).to be_valid
        end

        it "doesn't allow more than the maximum number of images" do
          expect(post_two_images).not_to be_valid
        end

        it "doesn't allow more than the maximum number of embedded media items" do
          expect(post_with_two_embedded_media).not_to be_valid
        end

        it "doesn't allow a new user to edit their post to insert an image" do
          post_no_images.user.trust_level = TrustLevel[0]
          post_no_images.save
          expect {
            post_no_images.revise(post_no_images.user, raw: post_two_images.raw)
            post_no_images.reload
          }.not_to change(post_no_images, :raw)
        end
      end

      it "allows more images from a not-new account" do
        post_two_images.user.trust_level = TrustLevel[1]
        expect(post_two_images).to be_valid
      end
    end
  end

  describe "maximum attachments" do
    fab!(:newuser) { Fabricate(:user, trust_level: TrustLevel[0]) }
    let(:post_no_attachments) { Fabricate.build(:post, post_args.merge(user: newuser)) }
    let(:post_one_attachment) do
      post_with_body(
        "<a class='attachment' href='/#{upload_path}/1/2082985.txt'>file.txt</a>",
        newuser,
      )
    end
    let(:post_two_attachments) do
      post_with_body(
        "<a class='attachment' href='/#{upload_path}/2/20947092.log'>errors.log</a> <a class='attachment' href='/#{upload_path}/3/283572385.3ds'>model.3ds</a>",
        newuser,
      )
    end

    it "returns 0 attachments for an empty post" do
      expect(Fabricate.build(:post).attachment_count).to eq(0)
    end

    it "finds attachments from HTML" do
      expect(post_two_attachments.attachment_count).to eq(2)
    end

    context "with validation" do
      before { SiteSetting.newuser_max_attachments = 1 }

      context "with newuser" do
        it "allows a new user to post below the limit" do
          expect(post_one_attachment).to be_valid
        end

        it "doesn't allow more than the maximum" do
          expect(post_two_attachments).not_to be_valid
        end

        it "doesn't allow a new user to edit their post to insert an attachment" do
          post_no_attachments.user.trust_level = TrustLevel[0]
          post_no_attachments.save
          expect {
            post_no_attachments.revise(post_no_attachments.user, raw: post_two_attachments.raw)
            post_no_attachments.reload
          }.not_to change(post_no_attachments, :raw)
        end
      end

      it "allows more attachments from a not-new account" do
        post_two_attachments.user.trust_level = TrustLevel[1]
        expect(post_two_attachments).to be_valid
      end
    end
  end

  describe "links" do
    fab!(:newuser) { Fabricate(:user, trust_level: TrustLevel[0]) }
    let(:no_links) { post_with_body("hello world my name is evil trout", newuser) }
    let(:one_link) { post_with_body("[jlawr](http://www.imdb.com/name/nm2225369)", newuser) }
    let(:two_links) do
      post_with_body(
        "<a href='http://disneyland.disney.go.com/'>disney</a> <a href='http://reddit.com'>reddit</a>",
        newuser,
      )
    end
    let(:three_links) do
      post_with_body(
        "http://discourse.org and http://discourse.org/another_url and http://www.imdb.com/name/nm2225369",
        newuser,
      )
    end

    describe "raw_links" do
      it "returns a blank collection for a post with no links" do
        expect(no_links.raw_links).to be_blank
      end

      it "finds a link within markdown" do
        expect(one_link.raw_links).to eq(["http://www.imdb.com/name/nm2225369"])
      end

      it "can find two links from html" do
        expect(two_links.raw_links).to eq(%w[http://disneyland.disney.go.com/ http://reddit.com])
      end

      it "can find three links without markup" do
        expect(three_links.raw_links).to eq(
          %w[
            http://discourse.org
            http://discourse.org/another_url
            http://www.imdb.com/name/nm2225369
          ],
        )
      end
    end

    describe "linked_hosts" do
      it "returns blank with no links" do
        expect(no_links.linked_hosts).to be_blank
      end

      it "returns the host and a count for links" do
        expect(two_links.linked_hosts).to eq("disneyland.disney.go.com" => 1, "reddit.com" => 1)
      end

      it "it counts properly with more than one link on the same host" do
        expect(three_links.linked_hosts).to eq("discourse.org" => 1, "www.imdb.com" => 1)
      end
    end

    describe "total host usage" do
      it "has none for a regular post" do
        expect(no_links.total_hosts_usage).to be_blank
      end

      context "with a previous host" do
        let(:another_disney_link) do
          post_with_body(
            "[radiator springs](http://disneyland.disney.go.com/disney-california-adventure/radiator-springs-racers/)",
            newuser,
          )
        end

        before do
          another_disney_link.save
          TopicLink.extract_from(another_disney_link)
        end

        it "contains the new post's links, PLUS the previous one" do
          expect(two_links.total_hosts_usage).to eq(
            "disneyland.disney.go.com" => 2,
            "reddit.com" => 1,
          )
        end
      end
    end
  end

  describe "maximums" do
    fab!(:newuser) { Fabricate(:user, trust_level: TrustLevel[0]) }
    let(:post_one_link) do
      post_with_body("[sherlock](http://www.bbc.co.uk/programmes/b018ttws)", newuser)
    end
    let(:post_onebox) { post_with_body("http://www.google.com", newuser) }
    let(:post_code_link) { post_with_body("<code>http://www.google.com</code>", newuser) }
    let(:post_two_links) do
      post_with_body(
        "<a href='http://discourse.org'>discourse</a> <a href='http://twitter.com'>twitter</a>",
        newuser,
      )
    end
    let(:post_with_mentions) do
      post_with_body("hello @#{newuser.username} how are you doing?", newuser)
    end

    it "returns 0 links for an empty post" do
      expect(Fabricate.build(:post).link_count).to eq(0)
    end

    it "returns 0 links for a post with mentions" do
      expect(post_with_mentions.link_count).to eq(0)
    end

    it "finds links from markdown" do
      expect(post_one_link.link_count).to eq(1)
    end

    it "finds links from HTML" do
      expect(post_two_links.link_count).to eq(2)
    end

    context "with validation" do
      before { SiteSetting.newuser_max_links = 1 }

      context "with newuser" do
        it "returns true when within the amount of links allowed" do
          expect(post_one_link).to be_valid
        end

        it "doesn't allow more links than allowed" do
          expect(post_two_links).not_to be_valid
        end
      end

      it "allows multiple links for basic accounts" do
        post_two_links.user.trust_level = TrustLevel[1]
        expect(post_two_links).to be_valid
      end

      context "when posting links is limited to certain TL groups" do
        it "considers oneboxes links" do
          SiteSetting.post_links_allowed_groups = Group::AUTO_GROUPS[:trust_level_3]
          post_onebox.user.change_trust_level!(TrustLevel[2])
          expect(post_onebox).not_to be_valid
        end

        it "considers links within code" do
          SiteSetting.post_links_allowed_groups = Group::AUTO_GROUPS[:trust_level_3]
          post_onebox.user.change_trust_level!(TrustLevel[2])
          expect(post_code_link).not_to be_valid
        end

        it "doesn't allow allow links if user is not in allowed groups" do
          SiteSetting.post_links_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
          post_two_links.user.change_trust_level!(TrustLevel[1])
          expect(post_one_link).not_to be_valid
        end

        it "will skip the check for allowlisted domains" do
          SiteSetting.allowed_link_domains = "www.bbc.co.uk"
          SiteSetting.post_links_allowed_groups = "12"
          post_two_links.user.change_trust_level!(TrustLevel[1])
          expect(post_one_link).to be_valid
        end
      end
    end
  end

  describe "@mentions" do
    context "with raw_mentions" do
      it "returns an empty array with no matches" do
        post = Fabricate.build(:post, post_args.merge(raw: "Hello Jake and Finn!"))
        expect(post.raw_mentions).to eq([])
      end

      it "returns lowercase unique versions of the mentions" do
        post = Fabricate.build(:post, post_args.merge(raw: "@Jake @Finn @Jake"))
        expect(post.raw_mentions).to eq(%w[jake finn])
      end

      it "ignores pre" do
        # we need to force an inline
        post = Fabricate.build(:post, post_args.merge(raw: "p <pre>@Jake</pre> @Finn"))
        expect(post.raw_mentions).to eq(["finn"])
      end

      it "catches content between pre tags" do
        # per common mark we need to force an inline
        post = Fabricate.build(:post, post_args.merge(raw: "a <pre>hello</pre> @Finn <pre></pre>"))
        expect(post.raw_mentions).to eq(["finn"])
      end

      it "ignores code" do
        post = Fabricate.build(:post, post_args.merge(raw: "@Jake `@Finn`"))
        expect(post.raw_mentions).to eq(["jake"])
      end

      it "ignores quotes" do
        post =
          Fabricate.build(
            :post,
            post_args.merge(raw: "[quote=\"Evil Trout\"]\n@Jake\n[/quote]\n@Finn"),
          )
        expect(post.raw_mentions).to eq(["finn"])
      end

      it "handles underscore in username" do
        post = Fabricate.build(:post, post_args.merge(raw: "@Jake @Finn @Jake_Old"))
        expect(post.raw_mentions).to eq(%w[jake finn jake_old])
      end

      it "handles hyphen in groupname" do
        post = Fabricate.build(:post, post_args.merge(raw: "@org-board"))
        expect(post.raw_mentions).to eq(["org-board"])
      end
    end

    context "with max mentions" do
      fab!(:newuser) { Fabricate(:user, trust_level: TrustLevel[0]) }
      let(:post_with_one_mention) { post_with_body("@Jake is the person I'm mentioning", newuser) }
      let(:post_with_two_mentions) do
        post_with_body("@Jake @Finn are the people I'm mentioning", newuser)
      end

      context "with new user" do
        before do
          SiteSetting.newuser_max_mentions_per_post = 1
          SiteSetting.max_mentions_per_post = 5
        end

        it "allows a new user to have newuser_max_mentions_per_post mentions" do
          expect(post_with_one_mention).to be_valid
        end

        it "doesn't allow a new user to have more than newuser_max_mentions_per_post mentions" do
          expect(post_with_two_mentions).not_to be_valid
        end
      end

      context "when not a new user" do
        before do
          SiteSetting.newuser_max_mentions_per_post = 0
          SiteSetting.max_mentions_per_post = 1
        end

        it "allows max_mentions_per_post mentions" do
          post_with_one_mention.user.trust_level = TrustLevel[1]
          expect(post_with_one_mention).to be_valid
        end

        it "doesn't allow to have more than max_mentions_per_post mentions" do
          post_with_two_mentions.user.trust_level = TrustLevel[1]
          expect(post_with_two_mentions).not_to be_valid
        end
      end
    end
  end

  describe "validation" do
    it "validates our default post" do
      expect(Fabricate.build(:post, post_args)).to be_valid
    end

    it "create blank posts as invalid" do
      expect(Fabricate.build(:post, raw: "")).not_to be_valid
    end
  end

  describe "raw_hash" do
    let(:raw) { "this is our test post body" }
    let(:post) { post_with_body(raw) }

    it "returns a value" do
      expect(post.raw_hash).to be_present
    end

    it "returns blank for a nil body" do
      post.raw = nil
      expect(post.raw_hash).to be_blank
    end

    it "returns the same value for the same raw" do
      expect(post.raw_hash).to eq(post_with_body(raw).raw_hash)
    end

    it "returns a different value for a different raw" do
      expect(post.raw_hash).not_to eq(post_with_body("something else").raw_hash)
    end

    it "returns a different value with different text case" do
      expect(post.raw_hash).not_to eq(post_with_body("THIS is OUR TEST post BODy").raw_hash)
    end
  end

  describe "revise" do
    let(:post) { Fabricate(:post, post_args) }
    let(:first_version_at) { post.last_version_at }

    it "has no revision" do
      expect(post.revisions.size).to eq(0)
      expect(first_version_at).to be_present
      expect(post.revise(post.user, raw: post.raw)).to eq(false)
    end

    context "with the same body" do
      it "doesn't change version" do
        expect {
          post.revise(post.user, raw: post.raw)
          post.reload
        }.not_to change(post, :version)
      end
    end

    context "with grace period editing & edit windows" do
      before { SiteSetting.editing_grace_period = 1.minute.to_i }

      it "works" do
        revised_at = post.updated_at + 2.minutes
        new_revised_at = revised_at + 2.minutes

        # grace period edit
        post.revise(post.user, { raw: "updated body" }, revised_at: post.updated_at + 10.seconds)
        post.reload
        expect(post.version).to eq(1)
        expect(post.public_version).to eq(1)
        expect(post.revisions.size).to eq(0)
        expect(post.last_version_at.to_i).to eq(first_version_at.to_i)

        # revision much later
        post.revise(post.user, { raw: "another updated body" }, revised_at: revised_at)
        post.reload
        expect(post.version).to eq(2)
        expect(post.public_version).to eq(2)
        expect(post.revisions.size).to eq(1)
        expect(post.last_version_at.to_i).to eq(revised_at.to_i)

        # new edit window
        post.revise(
          post.user,
          { raw: "yet another updated body" },
          revised_at: revised_at + 10.seconds,
        )
        post.reload
        expect(post.version).to eq(2)
        expect(post.public_version).to eq(2)
        expect(post.revisions.size).to eq(1)
        expect(post.last_version_at.to_i).to eq(revised_at.to_i)

        # after second window
        post.revise(
          post.user,
          { raw: "yet another, another updated body" },
          revised_at: new_revised_at,
        )
        post.reload
        expect(post.version).to eq(3)
        expect(post.public_version).to eq(3)
        expect(post.revisions.size).to eq(2)
        expect(post.last_version_at.to_i).to eq(new_revised_at.to_i)
      end
    end

    context "with rate limiter" do
      let(:changed_by) { coding_horror }

      it "triggers a rate limiter" do
        EditRateLimiter.any_instance.expects(:performed!)
        post.revise(changed_by, raw: "updated body")
      end
    end

    context "with a new body" do
      let(:changed_by) { coding_horror }
      let!(:result) { post.revise(changed_by, raw: "updated body") }

      it "acts correctly" do
        expect(result).to eq(true)
        expect(post.raw).to eq("updated body")
        expect(post.invalidate_oneboxes).to eq(true)
        expect(post.version).to eq(2)
        expect(post.public_version).to eq(2)
        expect(post.revisions.size).to eq(1)
        expect(post.revisions.first.user).to be_present
      end

      context "when second poster posts again quickly" do
        it "is a grace period edit, because the second poster posted again quickly" do
          SiteSetting.editing_grace_period = 1.minute.to_i
          post.revise(
            changed_by,
            { raw: "yet another updated body" },
            revised_at: post.updated_at + 10.seconds,
          )
          post.reload

          expect(post.version).to eq(2)
          expect(post.public_version).to eq(2)
          expect(post.revisions.size).to eq(1)
        end
      end
    end
  end

  describe "before save" do
    let(:cooked) do
      "<p><div class=\"lightbox-wrapper\"><a data-download-href=\"//localhost:3000/#{upload_path}/34784374092783e2fef84b8bc96d9b54c11ceea0\" href=\"//localhost:3000/#{upload_path}/original/1X/34784374092783e2fef84b8bc96d9b54c11ceea0.gif\" class=\"lightbox\" title=\"Sword reworks.gif\"><img src=\"//localhost:3000/#{upload_path}/optimized/1X/34784374092783e2fef84b8bc96d9b54c11ceea0_1_690x276.gif\" width=\"690\" height=\"276\"><div class=\"meta\">\n<span class=\"filename\">Sword reworks.gif</span><span class=\"informations\">1000x400 1000 KB</span><span class=\"expand\"></span>\n</div></a></div></p>"
    end

    let(:post) do
      Fabricate(
        :post,
        raw:
          "<img src=\"/#{upload_path}/original/1X/34784374092783e2fef84b8bc96d9b54c11ceea0.gif\" width=\"690\" height=\"276\">",
        cooked: cooked,
      )
    end

    it "should not cook the post if raw has not been changed" do
      post.save!
      expect(post.cooked).to eq(cooked)
    end
  end

  describe "after save" do
    let(:post) { Fabricate(:post, post_args) }

    it "has correct info set" do
      expect(post.user_deleted?).to eq(false)
      expect(post.post_number).to be_present
      expect(post.excerpt).to be_present
      expect(post.post_type).to eq(Post.types[:regular])
      expect(post.revisions).to be_blank
      expect(post.cooked).to be_present
      expect(post.external_id).to be_present
      expect(post.quote_count).to eq(0)
      expect(post.replies).to be_blank
    end

    context "with extract_quoted_post_numbers" do
      let!(:post) { Fabricate(:post, post_args) }
      let(:reply) { Fabricate.build(:post, post_args) }

      it "finds the quote when in the same topic" do
        reply.raw =
          "[quote=\"EvilTrout, post:#{post.post_number}, topic:#{post.topic_id}\"]hello[/quote]"
        reply.extract_quoted_post_numbers
        expect(reply.quoted_post_numbers).to eq([post.post_number])
      end

      it "doesn't find the quote in a different topic" do
        reply.raw =
          "[quote=\"EvilTrout, post:#{post.post_number}, topic:#{post.topic_id + 1}\"]hello[/quote]"
        reply.extract_quoted_post_numbers
        expect(reply.quoted_post_numbers).to be_blank
      end

      it "doesn't find the quote in the same post" do
        reply = Fabricate.build(:post, post_args.merge(post_number: 646))
        reply.raw =
          "[quote=\"EvilTrout, post:#{reply.post_number}, topic:#{post.topic_id}\"]hello[/quote]"
        reply.extract_quoted_post_numbers
        expect(reply.quoted_post_numbers).to be_blank
      end
    end

    context "with a new reply" do
      fab!(:topic)
      let(:other_user) { coding_horror }
      let(:reply_text) { "[quote=\"Evil Trout, post:1\"]\nhello\n[/quote]\nHmmm!" }
      let!(:post) do
        PostCreator.new(topic.user, raw: Fabricate.build(:post).raw, topic_id: topic.id).create
      end
      let!(:reply) do
        PostCreator.new(
          other_user,
          raw: reply_text,
          topic_id: topic.id,
          reply_to_post_number: post.post_number,
        ).create
      end

      it "has a quote" do
        expect(reply.quote_count).to eq(1)
      end

      it "has a reply to the user of the original user" do
        expect(reply.reply_to_user).to eq(post.user)
      end

      it "increases the reply count of the parent" do
        post.reload
        expect(post.reply_count).to eq(1)
      end

      it "increases the reply count of the topic" do
        topic.reload
        expect(topic.reply_count).to eq(1)
      end

      it "is the child of the parent post" do
        expect(post.replies).to eq([reply])
      end

      it "doesn't change the post count when you edit the reply" do
        reply.raw = "updated raw"
        reply.save
        post.reload
        expect(post.reply_count).to eq(1)
      end

      context "with a multi-quote reply" do
        let!(:multi_reply) do
          raw =
            "[quote=\"Evil Trout, post:1\"]post1 quote[/quote]\nAha!\n[quote=\"Evil Trout, post:2\"]post2 quote[/quote]\nNeat-o"
          PostCreator.new(
            other_user,
            raw: raw,
            topic_id: topic.id,
            reply_to_post_number: post.post_number,
          ).create
        end

        it "has the correct info set" do
          expect(multi_reply.quote_count).to eq(2)
          expect(post.replies.include?(multi_reply)).to eq(true)
          expect(reply.replies.include?(multi_reply)).to eq(true)
        end
      end
    end
  end

  describe "summary" do
    let!(:p1) { Fabricate(:post, post_args.merge(score: 4, percent_rank: 0.33)) }
    let!(:p2) { Fabricate(:post, post_args.merge(score: 10, percent_rank: 0.66)) }
    let!(:p3) { Fabricate(:post, post_args.merge(score: 5, percent_rank: 0.99)) }
    fab!(:p4) { Fabricate(:post, percent_rank: 0.99) }

    it "returns the OP and posts above the threshold in summary mode" do
      SiteSetting.summary_percent_filter = 66
      expect(Post.summary(topic.id).order(:post_number)).to eq([p1, p2])
      expect(Post.summary(p4.topic.id)).to eq([p4])
    end
  end

  describe "sort_order" do
    context "with a regular topic" do
      let!(:p1) { Fabricate(:post, post_args) }
      let!(:p2) { Fabricate(:post, post_args) }
      let!(:p3) { Fabricate(:post, post_args) }

      it "defaults to created order" do
        expect(Post.regular_order).to eq([p1, p2, p3])
      end
    end
  end

  describe "reply_ids" do
    fab!(:topic)
    let!(:p1) { Fabricate(:post, topic: topic, post_number: 1) }
    let!(:p2) { Fabricate(:post, topic: topic, post_number: 2, reply_to_post_number: 1) }
    let!(:p3) { Fabricate(:post, topic: topic, post_number: 3) }
    let!(:p4) { Fabricate(:post, topic: topic, post_number: 4, reply_to_post_number: 2) }
    let!(:p5) { Fabricate(:post, topic: topic, post_number: 5, reply_to_post_number: 4) }
    let!(:p6) { Fabricate(:post, topic: topic, post_number: 6) }

    before do
      PostReply.create!(post: p1, reply: p2)
      PostReply.create!(post: p2, reply: p4)
      PostReply.create!(post: p2, reply: p6) # simulates p6 quoting p2
      PostReply.create!(post: p3, reply: p5) # simulates p5 quoting p3
      PostReply.create!(post: p4, reply: p5)
      PostReply.create!(post: p6, reply: p6) # https://meta.discourse.org/t/topic-quoting-itself-displays-reply-indicator/76085
    end

    it "returns the reply ids and their level" do
      expect(p1.reply_ids).to eq(
        [{ id: p2.id, level: 1 }, { id: p4.id, level: 2 }, { id: p6.id, level: 2 }],
      )
      expect(p2.reply_ids).to eq([{ id: p4.id, level: 1 }, { id: p6.id, level: 1 }])
      expect(p3.reply_ids).to be_empty # has no replies
      expect(p4.reply_ids).to be_empty # p5 replies to 2 posts (p4 and p3)
      expect(p5.reply_ids).to be_empty # has no replies
      expect(p6.reply_ids).to be_empty # quotes itself
    end

    it "ignores posts moved to other topics" do
      p2.update_column(:topic_id, Fabricate(:topic).id)
      expect(p1.reply_ids).to be_blank
    end

    it "doesn't include the same reply twice" do
      PostReply.create!(post: p4, reply: p1)
      expect(p1.reply_ids.size).to eq(4)
    end

    it "does not skip any replies" do
      expect(p1.reply_ids(only_replies_to_single_post: false)).to eq(
        [
          { id: p2.id, level: 1 },
          { id: p4.id, level: 2 },
          { id: p5.id, level: 3 },
          { id: p6.id, level: 2 },
        ],
      )
      expect(p2.reply_ids(only_replies_to_single_post: false)).to eq(
        [{ id: p4.id, level: 1 }, { id: p5.id, level: 2 }, { id: p6.id, level: 1 }],
      )
      expect(p3.reply_ids(only_replies_to_single_post: false)).to eq([{ id: p5.id, level: 1 }])
      expect(p4.reply_ids(only_replies_to_single_post: false)).to eq([{ id: p5.id, level: 1 }])
      expect(p5.reply_ids(only_replies_to_single_post: false)).to be_empty # has no replies
      expect(p6.reply_ids(only_replies_to_single_post: false)).to be_empty # quotes itself
    end
  end

  describe "urls" do
    it "no-ops for empty list" do
      expect(Post.urls([])).to eq({})
    end

    # integration test -> should move to centralized integration test
    it "finds urls for posts presented" do
      p1 = Fabricate(:post)
      p2 = Fabricate(:post)
      expect(Post.urls([p1.id, p2.id])).to eq(p1.id => p1.url, p2.id => p2.url)
    end
  end

  describe "details" do
    it "adds details" do
      post = Fabricate.build(:post)
      post.add_detail("key", "value")
      expect(post.post_details.size).to eq(1)
      expect(post.post_details.first.key).to eq("key")
      expect(post.post_details.first.value).to eq("value")
    end

    it "can find a post by a detail" do
      detail = Fabricate(:post_detail)
      post = detail.post
      expect(Post.find_by_detail(detail.key, detail.value).id).to eq(post.id)
    end
  end

  describe "cooking" do
    let(:post) do
      Fabricate.build(
        :post,
        post_args.merge(
          raw: "please read my blog http://blog.example.com",
          user: Fabricate(:user, refresh_auto_groups: true),
        ),
      )
    end

    it "should unconditionally follow links for staff" do
      SiteSetting.tl3_links_no_follow = true
      post.user.trust_level = 1
      post.user.moderator = true
      post.save

      expect(post.cooked).not_to match(/nofollow/)
    end

    it "should add nofollow to links in the post for trust levels below 3" do
      post.user.trust_level = 2
      post.save
      expect(post.cooked).to match(/noopener nofollow ugc/)
    end

    it "when tl3_links_no_follow is false, should not add nofollow for trust level 3 and higher" do
      SiteSetting.tl3_links_no_follow = false
      post.user.trust_level = 3
      post.save
      expect(post.cooked).not_to match(/nofollow/)
    end

    it "when tl3_links_no_follow is true, should add nofollow for trust level 3 and higher" do
      SiteSetting.tl3_links_no_follow = true
      post.user.trust_level = 3
      post.save
      expect(post.cooked).to match(/noopener nofollow ugc/)
    end

    it "passes the last_editor_id as the markdown user_id option and post_id" do
      post.save
      post.reload
      PostAnalyzer
        .any_instance
        .expects(:cook)
        .with(
          post.raw,
          {
            cook_method: Post.cook_methods[:regular],
            user_id: post.last_editor_id,
            post_id: post.id,
          },
        )
      post.cook(post.raw)
      user_editor = Fabricate(:user)
      post.update!(last_editor_id: user_editor.id)
      PostAnalyzer
        .any_instance
        .expects(:cook)
        .with(
          post.raw,
          { cook_method: Post.cook_methods[:regular], user_id: user_editor.id, post_id: post.id },
        )
      post.cook(post.raw)
    end

    describe "mentions" do
      fab!(:group) do
        Fabricate(
          :group,
          visibility_level: Group.visibility_levels[:members],
          mentionable_level: Group::ALIAS_LEVELS[:members_mods_and_admins],
        )
      end

      before { Jobs.run_immediately! }

      describe "when user can not mention a group" do
        it "should not create the mention with the notify class" do
          post = Fabricate(:post, raw: "hello @#{group.name}")
          post.trigger_post_process
          post.reload

          expect(post.cooked).to eq(
            %Q|<p>hello <a class="mention-group" href="/groups/#{group.name}">@#{group.name}</a></p>|,
          )
        end
      end

      describe "when user can mention a group" do
        before { group.add(post.user) }

        it "should create the mention" do
          post.update!(raw: "hello @#{group.name}")
          post.trigger_post_process
          post.reload

          expect(post.cooked).to eq(
            %Q|<p>hello <a class="mention-group notify" href="/groups/#{group.name}">@#{group.name}</a></p>|,
          )
        end
      end

      describe "when group owner can mention a group" do
        before do
          group.update!(mentionable_level: Group::ALIAS_LEVELS[:owners_mods_and_admins])
          group.add_owner(post.user)
        end

        it "should create the mention" do
          post.update!(raw: "hello @#{group.name}")
          post.trigger_post_process
          post.reload

          expect(post.cooked).to eq(
            %Q|<p>hello <a class="mention-group notify" href="/groups/#{group.name}">@#{group.name}</a></p>|,
          )
        end
      end
    end
  end

  describe "has_host_spam" do
    let(:raw) do
      "hello from my site http://www.example.net http://#{GlobalSetting.hostname} http://#{RailsMultisite::ConnectionManagement.current_hostname}"
    end

    it "correctly detects host spam" do
      post = Fabricate(:post, raw: raw)

      expect(post.total_hosts_usage).to eq("www.example.net" => 1)
      post.acting_user.trust_level = 0

      expect(post.has_host_spam?).to eq(false)

      SiteSetting.newuser_spam_host_threshold = 1

      expect(post.has_host_spam?).to eq(true)

      SiteSetting.allowed_spam_host_domains = "bla.com|boo.com | example.net "
      expect(post.has_host_spam?).to eq(false)
    end

    it "doesn't punish staged users" do
      SiteSetting.newuser_spam_host_threshold = 1
      user = Fabricate(:user, staged: true, trust_level: 0)
      post = Fabricate(:post, raw: raw, user: user)
      expect(post.has_host_spam?).to eq(false)
    end

    it "punishes previously staged users that were created within 1 day" do
      SiteSetting.newuser_spam_host_threshold = 1
      SiteSetting.newuser_max_links = 3
      user = Fabricate(:user, staged: true, trust_level: 0)
      user.created_at = 1.hour.ago
      user.unstage!
      post = Fabricate(:post, raw: raw, user: user)
      expect(post.has_host_spam?).to eq(true)
    end

    it "doesn't punish previously staged users over 1 day old" do
      SiteSetting.newuser_spam_host_threshold = 1
      SiteSetting.newuser_max_links = 3
      user = Fabricate(:user, staged: true, trust_level: 0)
      user.created_at = 2.days.ago
      user.unstage!
      post = Fabricate(:post, raw: raw, user: user)
      expect(post.has_host_spam?).to eq(false)
    end

    it "ignores private messages" do
      SiteSetting.newuser_spam_host_threshold = 1
      user = Fabricate(:user, trust_level: 0)
      post =
        Fabricate(:post, raw: raw, user: user, topic: Fabricate(:private_message_topic, user: user))
      expect(post.has_host_spam?).to eq(false)
    end
  end

  it "has custom fields" do
    post = Fabricate(:post)
    expect(post.custom_fields["a"]).to eq(nil)

    post.custom_fields["Tommy"] = "Hanks"
    post.custom_fields["Vincent"] = "Vega"
    post.save

    post = Post.find(post.id)
    expect(post.custom_fields).to eq("Tommy" => "Hanks", "Vincent" => "Vega")
  end

  describe "#excerpt_for_topic" do
    it "returns a topic excerpt, defaulting to 220 chars" do
      expected_excerpt =
        "This is a sample post with semi-long raw content. The raw content is also more than \ntwo hundred characters to satisfy any test conditions that require content longer \nthan the typical test post raw content. It really is&hellip;"
      post = Fabricate(:post_with_long_raw_content)
      post.rebake!
      excerpt = post.excerpt_for_topic
      expect(excerpt).to eq(expected_excerpt)
    end

    it "respects the site setting for topic excerpt" do
      SiteSetting.topic_excerpt_maxlength = 10
      expected_excerpt = "This is a &hellip;"
      post = Fabricate(:post_with_long_raw_content)
      post.rebake!
      excerpt = post.excerpt_for_topic
      expect(excerpt).to eq(expected_excerpt)
    end
  end

  describe "#rebake!" do
    it "will rebake a post correctly" do
      post = create_post
      expect(post.baked_at).not_to eq(nil)
      first_baked = post.baked_at
      first_cooked = post.cooked

      DB.exec("UPDATE posts SET cooked = 'frogs' WHERE id = ?", [post.id])
      post.reload

      post.expects(:publish_change_to_clients!).with(:rebaked)

      result = post.rebake!

      expect(post.baked_at).not_to eq_time(first_baked)
      expect(post.cooked).to eq(first_cooked)
      expect(result).to eq(true)
    end

    it "updates the topic excerpt at the same time if it is the OP" do
      post = create_post
      post.topic.update(excerpt: "test")
      DB.exec("UPDATE posts SET cooked = 'frogs' WHERE id = ?", [post.id])
      post.reload
      result = post.rebake!
      post.topic.reload
      expect(post.topic.excerpt).not_to eq("test")
    end

    it "does not update the topic excerpt if the post is not the OP" do
      post = create_post
      post2 = create_post
      post.topic.update(excerpt: "test")
      result = post2.rebake!
      post.topic.reload
      expect(post.topic.excerpt).to eq("test")
    end

    it "works with posts in deleted topics" do
      post = create_post
      post.topic.trash!
      post.reload
      post.rebake!
    end

    it "uses inline onebox cache by default" do
      Jobs.run_immediately!
      stub_request(:get, "http://testonebox.com/vvf").to_return(status: 200, body: <<~HTML)
        <html><head>
          <title>hello this is Testonebox!</title>
        </head></html>
      HTML
      post = create_post(raw: <<~POST).reload
        hello inline onebox http://testonebox.com/vvf
      POST
      expect(post.cooked).to include("hello this is Testonebox!")

      stub_request(:get, "http://testonebox.com/vvf").to_return(status: 200, body: <<~HTML)
        <html><head>
          <title>hello this is updated Testonebox!</title>
        </head></html>
      HTML
      post.rebake!
      expect(post.reload.cooked).to include("hello this is Testonebox!")
    ensure
      InlineOneboxer.invalidate("http://testonebox.com/vvf")
    end

    it "passing invalidate_oneboxes: true ignores inline onebox cache" do
      Jobs.run_immediately!
      stub_request(:get, "http://testonebox.com/vvf22").to_return(status: 200, body: <<~HTML)
        <html><head>
          <title>hello this is Testonebox!</title>
        </head></html>
      HTML
      post = create_post(raw: <<~POST).reload
        hello inline onebox http://testonebox.com/vvf22
      POST
      expect(post.cooked).to include("hello this is Testonebox!")

      stub_request(:get, "http://testonebox.com/vvf22").to_return(status: 200, body: <<~HTML)
        <html><head>
          <title>hello this is updated Testonebox!</title>
        </head></html>
      HTML
      post.rebake!(invalidate_oneboxes: true)
      expect(post.reload.cooked).to include("hello this is updated Testonebox!")
    ensure
      InlineOneboxer.invalidate("http://testonebox.com/vvf22")
    end
  end

  describe "#set_owner" do
    fab!(:post)

    it "will change owner of a post correctly" do
      post.set_owner(coding_horror, Discourse.system_user)
      post.reload

      expect(post.user).to eq(coding_horror)
      expect(post.revisions.size).to eq(1)
    end

    it "skips creating new post revision if skip_revision is true" do
      post.set_owner(coding_horror, Discourse.system_user, true)
      post.reload

      expect(post.user).to eq(coding_horror)
      expect(post.revisions.size).to eq(0)
    end

    it "uses default locale for edit reason" do
      I18n.locale = "de"

      post.set_owner(coding_horror, Discourse.system_user)
      post.reload

      expected_reason =
        I18n.with_locale(SiteSetting.default_locale) { I18n.t("change_owner.post_revision_text") }

      expect(post.edit_reason).to eq(expected_reason)
    end
  end

  describe ".rebake_old" do
    it "will catch posts it needs to rebake" do
      post = create_post
      post.update_columns(baked_at: Time.new(2000, 1, 1), baked_version: -1)
      Post.rebake_old(100)

      post.reload
      expect(post.baked_at).to be > 1.day.ago

      baked = post.baked_at
      Post.rebake_old(100)
      post.reload
      expect(post.baked_at).to eq_time(baked)
    end

    it "will rate limit globally" do
      post1 = create_post
      post2 = create_post
      post3 = create_post

      Post.where(id: [post1.id, post2.id, post3.id]).update_all(baked_version: -1)

      global_setting :max_old_rebakes_per_15_minutes, 2

      RateLimiter.clear_all_global!
      RateLimiter.enable

      Post.rebake_old(100)

      expect(post3.reload.baked_version).not_to eq(-1)
      expect(post2.reload.baked_version).not_to eq(-1)
      expect(post1.reload.baked_version).to eq(-1)
    end
  end

  describe "#hide!" do
    fab!(:post)

    after { Discourse.redis.flushdb }

    it "should not run post validations" do
      PostValidator.any_instance.expects(:validate).never

      expect { post.hide!(PostActionType.types[:off_topic]) }.to change { post.reload.hidden }.from(
        false,
      ).to(true)
    end

    it "should decrease user_stat topic_count for first post" do
      expect do post.hide!(PostActionType.types[:off_topic]) end.to change {
        post.user.user_stat.reload.topic_count
      }.from(1).to(0)
    end

    it "should decrease user_stat post_count" do
      post_2 = Fabricate(:post, topic: post.topic, user: post.user)

      expect do post_2.hide!(PostActionType.types[:off_topic]) end.to change {
        post_2.user.user_stat.reload.post_count
      }.from(1).to(0)
    end
  end

  describe "#unhide!" do
    fab!(:post)

    before { SiteSetting.unique_posts_mins = 5 }

    it "will unhide the first post & make the topic visible" do
      hidden_topic = Fabricate(:topic, visible: false)

      post = create_post(topic: hidden_topic)
      post.update_columns(hidden: true, hidden_at: Time.now, hidden_reason_id: 1)
      post.reload

      expect(post.hidden).to eq(true)

      post.expects(:publish_change_to_clients!).with(:acted)

      post.unhide!

      post.reload
      hidden_topic.reload

      expect(post.hidden).to eq(false)
      expect(hidden_topic.visible).to eq(true)
      expect(hidden_topic.visibility_reason_id).to eq(Topic.visibility_reasons[:op_unhidden])
    end

    it "will not unhide the topic if the topic visibility_reason_id is not op_flag_threshold_reached" do
      hidden_topic =
        Fabricate(
          :topic,
          visible: false,
          visibility_reason_id: Topic.visibility_reasons[:manually_unlisted],
        )
      post = create_post(topic: hidden_topic)
      post.update_columns(hidden: true, hidden_at: Time.now, hidden_reason_id: 1)
      post.reload

      expect(post.hidden).to eq(true)
      post.unhide!

      hidden_topic.reload
      expect(hidden_topic.visible).to eq(false)
    end

    it "should increase user_stat topic_count for first post" do
      post.hide!(PostActionType.types[:off_topic])

      expect do post.unhide! end.to change { post.user.user_stat.reload.topic_count }.from(0).to(1)
    end

    it "should decrease user_stat post_count" do
      post_2 = Fabricate(:post, topic: post.topic, user: post.user)
      post_2.hide!(PostActionType.types[:off_topic])

      expect do post_2.unhide! end.to change { post_2.user.user_stat.reload.post_count }.from(0).to(
        1,
      )
    end
  end

  it "will unhide the post but will keep the topic invisible/unlisted" do
    hidden_topic = Fabricate(:topic, visible: false)
    create_post(topic: hidden_topic)
    second_post = create_post(topic: hidden_topic)

    second_post.update_columns(hidden: true, hidden_at: Time.now, hidden_reason_id: 1)
    second_post.expects(:publish_change_to_clients!).with(:acted)

    second_post.unhide!

    second_post.reload
    hidden_topic.reload

    expect(second_post.hidden).to eq(false)
    expect(hidden_topic.visible).to eq(false)
  end

  it "automatically orders post revisions by number ascending" do
    post = Fabricate(:post)
    post.revisions.create!(user_id: 1, post_id: post.id, number: 2)
    post.revisions.create!(user_id: 1, post_id: post.id, number: 1)
    expect(post.revisions.pluck(:number)).to eq([1, 2])
  end

  describe "video_thumbnails" do
    fab!(:video_upload) { Fabricate(:upload, extension: "mp4") }
    fab!(:image_upload) { Fabricate(:upload) }
    fab!(:image_upload_2) { Fabricate(:upload) }
    let(:base_url) { "#{Discourse.base_url_no_prefix}#{Discourse.base_path}" }
    let(:video_url) { "#{base_url}#{video_upload.url}" }

    let(:raw_video) { <<~RAW }
      <video width="100%" height="100%" controls>
        <source src="#{video_url}">
        <a href="#{video_url}">#{video_url}</a>
      </video>
      RAW

    let(:post) { Fabricate(:post, raw: raw_video) }

    before { SiteSetting.video_thumbnails_enabled = true }

    it "has a topic thumbnail" do
      # Thumbnails are tied to a specific video file by using the
      # video's sha1 as the image filename
      image_upload.original_filename = "#{video_upload.sha1}.png"
      image_upload.save!
      post.link_post_uploads

      post.topic.reload
      expect(post.topic.topic_thumbnails.length).to eq(1)
    end

    it "only applies for video uploads" do
      image_upload.original_filename = "#{image_upload_2.sha1}.png"
      image_upload.save!
      post.link_post_uploads

      post.topic.reload
      expect(post.topic.topic_thumbnails.length).to eq(0)
    end

    it "does not overwrite existing thumbnails" do
      image_upload.original_filename = "#{video_upload.sha1}.png"
      image_upload.save!
      post.topic.image_upload_id = image_upload_2.id
      post.topic.save!
      post.link_post_uploads

      post.topic.reload
      expect(post.topic.image_upload_id).to eq(image_upload_2.id)
    end

    it "uses the newest thumbnail" do
      image_upload.original_filename = "#{video_upload.sha1}.png"
      image_upload.save!
      image_upload_2.original_filename = "#{video_upload.sha1}.png"
      image_upload_2.save!
      post.link_post_uploads

      post.topic.reload
      expect(post.topic.topic_thumbnails.length).to eq(1)
      expect(post.topic.image_upload_id).to eq(image_upload_2.id)
    end

    it "does not create thumbnails when disabled" do
      SiteSetting.video_thumbnails_enabled = false
      image_upload.original_filename = "#{video_upload.sha1}.png"
      image_upload.save!
      post.link_post_uploads

      post.topic.reload
      expect(post.topic.topic_thumbnails.length).to eq(0)
    end
  end

  describe "uploads" do
    fab!(:video_upload) { Fabricate(:upload, extension: "mp4") }
    fab!(:video_upload_2) { Fabricate(:upload, extension: "mp4") }
    fab!(:image_upload) { Fabricate(:upload) }
    fab!(:audio_upload) { Fabricate(:upload, extension: "ogg") }
    fab!(:attachment_upload) { Fabricate(:upload, extension: "csv") }
    fab!(:attachment_upload_2) { Fabricate(:upload) }
    fab!(:attachment_upload_3) { Fabricate(:upload, extension: nil) }

    let(:base_url) { "#{Discourse.base_url_no_prefix}#{Discourse.base_path}" }
    let(:video_url) { "#{base_url}#{video_upload.url}" }
    let(:video_2_url) { "#{base_url}#{video_upload_2.url}" }
    let(:audio_url) { "#{base_url}#{audio_upload.url}" }

    let(:raw_multiple) { <<~RAW }
      <a href="#{attachment_upload.url}">Link</a>
      [test|attachment](#{attachment_upload_2.short_url})
      [test3|attachment](#{attachment_upload_3.short_url})
      <img src="#{image_upload.url}">

      <video width="100%" height="100%" controls>
        <source src="#{video_url}">
        <a href="#{video_url}">#{video_url}</a>
      </video>

      <audio controls>
        <source src="#{audio_url}">
        <a href="#{audio_url}">#{audio_url}</a>
      </audio>

      <div class="video-placeholder-container" data-video-src="#{video_2_url}" dir="ltr" style="cursor: pointer;">
        <div class="video-placeholder-wrapper">
          <div class="video-placeholder-overlay">
            <svg class="fa d-icon d-icon-play svg-icon svg-string" xmlns="http://www.w3.org/2000/svg">
              <use href="#play"></use>
            </svg>
          </div>
        </div>
      </div>
      RAW

    let(:post) { Fabricate(:post, raw: raw_multiple) }

    it "removes post uploads on destroy" do
      post.link_post_uploads

      post.trash!
      expect(UploadReference.count).to eq(7)

      post.destroy!
      expect(UploadReference.count).to eq(0)
    end

    describe "#link_post_uploads" do
      it "finds all the uploads in the post" do
        post.link_post_uploads

        expect(UploadReference.where(target: post).pluck(:upload_id)).to contain_exactly(
          video_upload.id,
          video_upload_2.id,
          image_upload.id,
          audio_upload.id,
          attachment_upload.id,
          attachment_upload_2.id,
          attachment_upload_3.id,
        )
      end

      it "cleans the reverse index up for the current post" do
        post.link_post_uploads

        post_uploads_ids = post.upload_references.pluck(:id)

        post.link_post_uploads

        expect(post.reload.upload_references.pluck(:id)).to_not contain_exactly(post_uploads_ids)
      end

      context "when secure uploads is enabled" do
        before do
          setup_s3
          SiteSetting.authorized_extensions = "pdf|png|jpg|csv"
          SiteSetting.secure_uploads = true
        end

        it "sets the access_control_post_id on uploads in the post that don't already have the value set" do
          other_post = Fabricate(:post)
          video_upload.update(access_control_post_id: other_post.id)
          audio_upload.update(access_control_post_id: other_post.id)

          post.link_post_uploads

          image_upload.reload
          video_upload.reload
          expect(image_upload.access_control_post_id).to eq(post.id)
          expect(video_upload.access_control_post_id).not_to eq(post.id)
        end

        context "for custom emoji" do
          before { CustomEmoji.create(name: "meme", upload: image_upload) }
          it "never sets an access control post because they should not be secure" do
            post.link_post_uploads
            expect(image_upload.reload.access_control_post_id).to eq(nil)
          end
        end
      end
    end

    describe "#update_uploads_secure_status" do
      fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }

      let(:raw) { <<~RAW }
        <a href="#{attachment_upload.url}">Link</a>
        <img src="#{image_upload.url}">
        RAW

      before do
        Jobs.run_immediately!

        setup_s3
        SiteSetting.authorized_extensions = "pdf|png|jpg|csv"
        SiteSetting.secure_uploads = true

        attachment_upload.update!(original_filename: "hello.csv")

        stub_upload(attachment_upload)
        stub_upload(image_upload)
      end

      it "marks image and attachment uploads as secure in PMs when secure_uploads is ON" do
        SiteSetting.secure_uploads = true
        post =
          Fabricate(
            :post,
            raw: raw,
            user: user,
            topic: Fabricate(:private_message_topic, user: user),
          )
        post.link_post_uploads
        post.update_uploads_secure_status(source: "test")

        expect(
          UploadReference.where(target: post).joins(:upload).pluck(:upload_id, :secure),
        ).to contain_exactly([attachment_upload.id, true], [image_upload.id, true])
      end

      it "marks image uploads as not secure in PMs when when secure_uploads is ON" do
        SiteSetting.secure_uploads = false
        post =
          Fabricate(
            :post,
            raw: raw,
            user: user,
            topic: Fabricate(:private_message_topic, user: user),
          )
        post.link_post_uploads
        post.update_uploads_secure_status(source: "test")

        expect(
          UploadReference.where(target: post).joins(:upload).pluck(:upload_id, :secure),
        ).to contain_exactly([attachment_upload.id, false], [image_upload.id, false])
      end

      it "marks attachments as secure when relevant setting is enabled" do
        SiteSetting.secure_uploads = true
        private_category = Fabricate(:private_category, group: Fabricate(:group))
        post =
          Fabricate(
            :post,
            raw: raw,
            user: user,
            topic: Fabricate(:topic, user: user, category: private_category),
          )
        post.link_post_uploads
        post.update_uploads_secure_status(source: "test")

        expect(
          UploadReference.where(target: post).joins(:upload).pluck(:upload_id, :secure),
        ).to contain_exactly([attachment_upload.id, true], [image_upload.id, true])
      end

      it "does not mark an upload as secure if it has already been used in a public topic" do
        post = Fabricate(:post, raw: raw, user: user, topic: Fabricate(:topic, user: user))
        post.link_post_uploads
        post.update_uploads_secure_status(source: "test")

        pm =
          Fabricate(
            :post,
            raw: raw,
            user: user,
            topic: Fabricate(:private_message_topic, user: user),
          )
        pm.link_post_uploads
        pm.update_uploads_secure_status(source: "test")

        expect(
          UploadReference.where(target: pm).joins(:upload).pluck(:upload_id, :secure),
        ).to contain_exactly([attachment_upload.id, false], [image_upload.id, false])
      end
    end
  end

  describe "topic updated_at" do
    let :topic do
      create_post.topic
    end

    def updates_topic_updated_at
      time = freeze_time 1.day.from_now
      result = yield

      topic.reload
      expect(topic.updated_at).to eq_time(time)

      result
    end

    it "will update topic updated_at for all topic related events" do
      SiteSetting.whispers_allowed_groups = "#{Group::AUTO_GROUPS[:staff]}"

      post =
        updates_topic_updated_at do
          create_post(topic_id: topic.id, post_type: Post.types[:whisper])
        end

      updates_topic_updated_at { PostDestroyer.new(Discourse.system_user, post).destroy }

      updates_topic_updated_at { PostDestroyer.new(Discourse.system_user, post).recover }
    end
  end

  describe "have_uploads" do
    it "should find all posts with the upload" do
      ids = []
      ids << Fabricate(
        :post,
        cooked: "A post with upload <img src='/#{upload_path}/1/defghijklmno.png'>",
      ).id
      ids << Fabricate(
        :post,
        cooked:
          "A post with optimized image <img src='/#{upload_path}/_optimized/601/961/defghijklmno.png'>",
      ).id
      Fabricate(:post)
      ids << Fabricate(
        :post,
        cooked: "A post with upload <img src='/#{upload_path}/original/1X/abc/defghijklmno.png'>",
      ).id
      ids << Fabricate(
        :post,
        cooked:
          "A post with upload link <a href='https://cdn.example.com/original/1X/abc/defghijklmno.png'>",
      ).id
      ids << Fabricate(
        :post,
        cooked:
          "A post with optimized image <img src='https://cdn.example.com/bucket/optimized/1X/abc/defghijklmno.png'>",
      ).id
      Fabricate(
        :post,
        cooked:
          "A post with external link <a href='https://example.com/wp-content/uploads/abcdef.gif'>",
      )
      ids << Fabricate(
        :post,
        cooked:
          'A post with missing upload <img src="https://cdn.example.com/images/transparent.png" data-orig-src="upload://defghijklmno.png">',
      ).id
      ids << Fabricate(
        :post,
        cooked:
          'A post with video upload <video width="100%" height="100%" controls=""><source src="https://cdn.example.com/uploads/short-url/XefghijklmU9.mp4"><a href="https://cdn.example.com/uploads/short-url/XefghijklmU9.mp4">https://cdn.example.com/uploads/short-url/XefghijklmU9.mp4</a></video>',
      ).id
      expect(Post.have_uploads.order(:id).pluck(:id)).to eq(ids)
    end
  end

  describe "#each_upload_url" do
    it "correctly identifies all upload urls" do
      SiteSetting.authorized_extensions = "*"
      upload1 = Fabricate(:upload)
      upload2 = Fabricate(:upload)
      upload3 = Fabricate(:video_upload)
      upload4 = Fabricate(:upload)
      upload5 = Fabricate(:upload)
      upload6 = Fabricate(:video_upload)
      upload7 = Fabricate(:upload, extension: "vtt")
      upload8 = Fabricate(:video_upload)

      set_cdn_url "https://awesome.com/somepath"

      post = Fabricate(:post, raw: <<~RAW)
      A post with image, video and link upload.

      ![](#{upload1.short_url})

      "#{GlobalSetting.cdn_url}#{upload4.url}"

      <a href='#{Discourse.base_url}#{upload2.url}'>Link to upload</a>
      ![](http://example.com/external.png)

      #{Discourse.base_url}#{upload3.short_path}

      <video poster="#{Discourse.base_url}#{upload5.url}">
        <source src="#{Discourse.base_url}#{upload6.url}" type="video/mp4" />
        <track src="#{Discourse.base_url}#{upload7.url}" label="English" kind="subtitles" srclang="en" default />
      </video>

      <div class="video-placeholder-container" data-video-src="#{Discourse.base_url}#{upload8.url}" dir="ltr" style="cursor: pointer;">
        <div class="video-placeholder-wrapper">
          <div class="video-placeholder-overlay">
            <svg class="fa d-icon d-icon-play svg-icon svg-string" xmlns="http://www.w3.org/2000/svg">
              <use href="#play"></use>
            </svg>
          </div>
        </div>
      </div>
      RAW

      urls = []
      paths = []

      post.each_upload_url do |src, path, _|
        urls << src
        paths << path
      end

      expect(urls).to contain_exactly(
        "#{GlobalSetting.cdn_url}#{upload1.url}",
        "#{GlobalSetting.cdn_url}#{upload4.url}",
        "#{Discourse.base_url}#{upload2.url}",
        "#{Discourse.base_url}#{upload3.short_path}",
        "#{Discourse.base_url}#{upload5.url}",
        "#{Discourse.base_url}#{upload6.url}",
        "#{Discourse.base_url}#{upload7.url}",
        "#{Discourse.base_url}#{upload8.url}",
      )

      expect(paths).to contain_exactly(
        upload1.url,
        upload4.url,
        upload2.url,
        nil,
        upload5.url,
        upload6.url,
        upload7.url,
        upload8.url,
      )
    end

    it "correctly identifies secure uploads" do
      setup_s3
      SiteSetting.authorized_extensions = "pdf|png|jpg|csv"
      SiteSetting.secure_uploads = true

      upload1 = Fabricate(:upload_s3, secure: true)
      upload2 = Fabricate(:upload_s3, secure: true)

      # Test including domain:
      upload1_url = UrlHelper.cook_url(upload1.url, secure: true)
      # Test without domain:
      upload2_path = URI.parse(UrlHelper.cook_url(upload2.url, secure: true)).path

      post = Fabricate(:post, raw: <<~RAW)
       <img src="#{upload1_url}"/>
       <img src="#{upload2_path}"/>
      RAW

      sha1s = []

      post.each_upload_url { |src, path, sha| sha1s << sha }

      expect(sha1s).to contain_exactly(upload1.sha1, upload2.sha1)
    end

    it "correctly identifies missing uploads with short url" do
      upload = Fabricate(:upload)
      url = upload.short_url
      sha1 = upload.sha1
      upload.destroy!

      post = Fabricate(:post, raw: "![upload](#{url})")

      urls = []
      paths = []
      sha1s = []

      post.each_upload_url do |src, path, sha|
        urls << src
        paths << path
        sha1s << sha
      end

      expect(urls).to contain_exactly(url)
      expect(paths).to contain_exactly(nil)
      expect(sha1s).to contain_exactly(sha1)
    end

    it "should skip external urls with upload url in query string" do
      setup_s3

      urls = []
      upload = Fabricate(:upload_s3)
      post =
        Fabricate(
          :post,
          raw:
            "<a href='https://link.example.com/redirect?url=#{Discourse.store.cdn_url(upload.url)}'>Link to upload</a>",
        )
      post.each_upload_url { |src, _, _| urls << src }
      expect(urls).to be_empty
    end

    it "should skip external URLs following the `/uploads/short-url` pattern if a host is present and the host is not the configured host" do
      upload = Fabricate(:upload)

      raw = <<~RAW
      [Upload link with Discourse.base_url](#{Discourse.base_url}/uploads/short-url/#{upload.sha1}.#{upload.extension})
      [Upload link without Discourse.base_url](https://some.other.host/uploads/short-url/#{upload.sha1}.#{upload.extension})
      [Upload link without host](/uploads/short-url/#{upload.sha1}.#{upload.extension})
      RAW

      post = Fabricate(:post, raw: raw)
      urls = []
      post.each_upload_url { |src, _, _| urls << src }

      expect(urls).to contain_exactly(
        "#{Discourse.base_url}/uploads/short-url/#{upload.sha1}.#{upload.extension}",
        "/uploads/short-url/#{upload.sha1}.#{upload.extension}",
      )
    end

    it "skip S3 cdn urls with different path" do
      setup_s3
      SiteSetting.Upload.stubs(:s3_cdn_url).returns("https://cdn.example.com/site1")

      urls = []
      raw =
        "<img src='https://cdn.example.com/site1/original/1X/bc68acbc8c022726e69f980e00d6811212r.jpg' /><img src='https://cdn.example.com/site2/original/1X/bc68acbc8c022726e69f980e00d68112128.jpg' />"
      post = Fabricate(:post, raw: raw)
      post.each_upload_url { |src, _, _| urls << src }
      expect(urls).to contain_exactly(
        "https://cdn.example.com/site1/original/1X/bc68acbc8c022726e69f980e00d6811212r.jpg",
      )
    end
  end

  describe "#publish_changes_to_client!" do
    fab!(:user1) { Fabricate(:user) }
    fab!(:user3) { Fabricate(:user) }
    fab!(:topic) { Fabricate(:private_message_topic, user: user1) }
    fab!(:post) { Fabricate(:post, topic: topic) }
    fab!(:group_user) { Fabricate(:group_user, user: user3) }
    fab!(:topic_allowed_group) do
      Fabricate(:topic_allowed_group, topic: topic, group: group_user.group)
    end
    let(:user2) { topic.allowed_users.last }

    it "send message to all users participating in private conversation" do
      freeze_time
      message = {
        id: post.id,
        post_number: post.post_number,
        updated_at: Time.now,
        user_id: post.user_id,
        last_editor_id: post.last_editor_id,
        type: :created,
        version: post.version,
      }

      messages =
        MessageBus.track_publish("/topic/#{topic.id}") { post.publish_change_to_clients!(:created) }

      created_message = messages.select { |msg| msg.data[:type] == :created }.first
      expect(created_message).to be_present
      expect(created_message.data).to eq(message)
      expect(created_message.user_ids.sort).to eq([user1.id, user2.id, user3.id].sort)

      stats_message = messages.select { |msg| msg.data[:type] == :created }.first
      expect(stats_message).to be_present
      expect(stats_message.user_ids.sort).to eq([user1.id, user2.id, user3.id].sort)
    end

    it "also publishes topic stats" do
      messages =
        MessageBus.track_publish("/topic/#{topic.id}") { post.publish_change_to_clients!(:created) }

      stats_message = messages.select { |msg| msg.data[:type] == :stats }.first
      expect(stats_message).to be_present
    end

    it "skips publishing topic stats when requested" do
      messages =
        MessageBus.track_publish("/topic/#{topic.id}") do
          post.publish_change_to_clients!(:anything, { skip_topic_stats: true })
        end

      stats_message = messages.select { |msg| msg.data[:type] == :stats }.first
      expect(stats_message).to be_blank

      # ensure that :skip_topic_stats did not get merged with the message
      other_message = messages.select { |msg| msg.data[:type] == :anything }.first
      expect(other_message).to be_present
      expect(other_message.data.key?(:skip_topic_stats)).to be_falsey
    end
  end

  describe "#cannot_permanently_delete_reason" do
    fab!(:post)
    fab!(:admin)

    before do
      freeze_time
      PostDestroyer.new(admin, post).destroy
    end

    it "returns error message if same admin and time did not pass" do
      expect(post.cannot_permanently_delete_reason(admin)).to eq(
        I18n.t(
          "post.cannot_permanently_delete.wait_or_different_admin",
          time_left: RateLimiter.time_left(Post::PERMANENT_DELETE_TIMER.to_i),
        ),
      )
    end

    it "returns nothing if different admin" do
      expect(post.cannot_permanently_delete_reason(Fabricate(:admin))).to eq(nil)
    end
  end

  describe "#canonical_url" do
    it "is able to determine correct canonical urls" do
      # ugly, but no interface to set this and we don't want to create
      # 100 posts to test this thing
      TopicView.stubs(:chunk_size).returns(2)

      post1 = Fabricate(:post)
      topic = post1.topic

      post2 = Fabricate(:post, topic: topic)
      post3 = Fabricate(:post, topic: topic)
      post4 = Fabricate(:post, topic: topic)

      topic_url = post1.topic.url

      expect(post1.canonical_url).to eq("#{topic_url}#post_#{post1.post_number}")
      expect(post2.canonical_url).to eq("#{topic_url}#post_#{post2.post_number}")

      expect(post3.canonical_url).to eq("#{topic_url}?page=2#post_#{post3.post_number}")
      expect(post4.canonical_url).to eq("#{topic_url}?page=2#post_#{post4.post_number}")
    end
  end

  describe "relative_url" do
    it "returns the correct post url with subfolder install" do
      set_subfolder "/forum"
      post = Fabricate(:post)

      expect(post.relative_url).to eq(
        "/forum/t/#{post.topic.slug}/#{post.topic.id}/#{post.post_number}",
      )
    end
  end

  describe "full_url" do
    it "returns the correct post url with subfolder install" do
      set_subfolder "/forum"
      post = Fabricate(:post)

      expect(post.full_url).to eq(
        "#{Discourse.base_url_no_prefix}/forum/t/#{post.topic.slug}/#{post.topic.id}/#{post.post_number}",
      )
    end
  end

  describe "public_posts_count_per_day" do
    before do
      freeze_time_safe

      Fabricate(:post)
      Fabricate(:post, created_at: 1.day.ago)
      Fabricate(:post, created_at: 1.day.ago)
      Fabricate(:post, created_at: 2.days.ago)
      Fabricate(:post, created_at: 4.days.ago)
    end

    let(:listable_topics_count_per_day) do
      { 1.day.ago.to_date => 2, 2.days.ago.to_date => 1, Time.now.utc.to_date => 1 }
    end

    it "collect closed interval public post count" do
      expect(Post.public_posts_count_per_day(2.days.ago, Time.now)).to include(
        listable_topics_count_per_day,
      )
      expect(Post.public_posts_count_per_day(2.days.ago, Time.now)).not_to include(
        4.days.ago.to_date => 1,
      )
    end

    it "returns the correct number of public posts per day when there are no public posts" do
      Fabricate(:post, post_type: Post.types[:whisper], created_at: 6.days.ago)
      Fabricate(:post, post_type: Post.types[:whisper], created_at: 7.days.ago)

      expect(Post.public_posts_count_per_day(10.days.ago, 5.days.ago)).to be_empty
    end

    it "returns the correct number of public posts per day with category filter" do
      category = Fabricate(:category)
      another_category = Fabricate(:category)

      topic = Fabricate(:topic, category: category)
      another_topic = Fabricate(:topic, category: another_category)

      Fabricate(:post, topic: topic, created_at: 6.days.ago)
      Fabricate(:post, topic: topic, created_at: 7.days.ago)
      Fabricate(:post, topic: another_topic, created_at: 6.days.ago)
      Fabricate(:post, topic: another_topic, created_at: 7.days.ago)

      expect(Post.public_posts_count_per_day(10.days.ago, 5.days.ago, category.id)).to eq(
        6.days.ago.to_date => 1,
        7.days.ago.to_date => 1,
      )

      expect(
        Post.public_posts_count_per_day(
          10.days.ago,
          5.days.ago,
          [category.id, another_category.id],
        ),
      ).to eq(6.days.ago.to_date => 2, 7.days.ago.to_date => 2)
    end

    it "returns the correct number of public posts per day with group filter" do
      user = Fabricate(:user)
      group_user = Fabricate(:user)
      group = Fabricate(:group)
      group.add(group_user)

      Fabricate(:post, user: user, created_at: 6.days.ago)
      Fabricate(:post, user: user, created_at: 7.days.ago)
      Fabricate(:post, user: group_user, created_at: 6.days.ago)
      Fabricate(:post, user: group_user, created_at: 7.days.ago)

      expect(
        Post.public_posts_count_per_day(10.days.ago, 5.days.ago, nil, false, [group.id]),
      ).to eq(6.days.ago.to_date => 1, 7.days.ago.to_date => 1)
    end
  end

  describe "#user_badges" do
    fab!(:user)
    fab!(:user2) { Fabricate(:user) }
    fab!(:post) { Fabricate(:post, user: user) }
    fab!(:post2) { Fabricate(:post, user: user) }

    # Create a badge that has all required flags set to true
    fab!(:badge1) do
      Badge.create!(
        name: "SomeBadge",
        badge_type_id: BadgeType::Bronze,
        listable: true,
        show_posts: true,
        post_header: true,
        multiple_grant: true,
      )
    end
    fab!(:ub1) do
      UserBadge.create!(
        badge_id: badge1.id,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
        post_id: post.id,
      )
    end

    # Create a badge that has the show_posts flag set to false
    fab!(:badge2) do
      Badge.create!(
        name: "SomeOtherBadge",
        badge_type_id: BadgeType::Bronze,
        listable: true,
        show_posts: false,
        post_header: true,
      )
    end
    fab!(:ub2) do
      UserBadge.create!(
        badge_id: badge2.id,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
        post_id: post.id,
      )
    end

    # Re-use our first badge, but on a different post
    fab!(:ub3) do
      UserBadge.create!(
        badge_id: badge1.id,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
        post_id: post2.id,
      )
    end

    # Now re-use our first badge, but on a different user
    fab!(:ub4) do
      UserBadge.create!(
        badge_id: badge1.id,
        user: user2,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
        post_id: post.id,
      )
    end

    # Create a badge that has the listable flag set to false
    fab!(:badge3) do
      Badge.create!(
        name: "WeirdBadge",
        badge_type_id: BadgeType::Bronze,
        listable: false,
        show_posts: true,
        post_header: true,
      )
    end
    fab!(:ub5) do
      UserBadge.create!(
        badge_id: badge3.id,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
        post_id: post.id,
      )
    end

    # Create a badge that has the post_header flag set to false
    fab!(:badge4) do
      Badge.create!(
        name: "StrangeBadge",
        badge_type_id: BadgeType::Bronze,
        listable: true,
        show_posts: true,
        post_header: false,
      )
    end
    fab!(:ub6) do
      UserBadge.create!(
        badge_id: badge4.id,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
        post_id: post.id,
      )
    end

    it "returns a user badge that was granted for this post" do
      expect(post.post_user_badges.pluck(:id)).to include(ub1.id)
    end

    it "does not return a user badge that has the show_posts flag set to false" do
      expect(post.post_user_badges.pluck(:id)).not_to include(ub2.id)
    end

    it "does not return a user badge that was not granted for this post" do
      expect(post.post_user_badges.pluck(:id)).not_to include(ub2.id)
    end

    it "does not return a user badge that was granted for a different user" do
      expect(post.post_user_badges.pluck(:id)).not_to include(ub4.id)
    end

    it "does not return a user badge that has the listable flag set to false" do
      expect(post.post_user_badges.pluck(:id)).not_to include(ub5.id)
    end

    it "does not return a user badge that has the post_header flag set to false" do
      expect(post.post_user_badges.pluck(:id)).not_to include(ub6.id)
    end
  end
end
