require 'spec_helper'

describe User do

  it { should have_many :posts }
  it { should have_many :notifications }
  it { should have_many :topic_users }
  it { should have_many :post_actions }
  it { should have_many :user_actions }
  it { should have_many :topics }
  it { should have_many :user_open_ids }
  it { should have_many :post_timings }
  it { should have_many :email_tokens }
  it { should have_many :views }
  it { should have_many :user_visits }
  it { should belong_to :approved_by }
  it { should have_many :email_logs }
  it { should have_many :topic_allowed_users }
  it { should have_many :invites }

  it { should validate_presence_of :username }
  it { should validate_presence_of :email }

  context '#update_view_counts' do

    let(:user) { Fabricate(:user) }

    context 'topics_entered' do
      context 'without any views' do
        it "doesn't increase the user's topics_entered" do
          lambda { User.update_view_counts; user.reload }.should_not change(user, :topics_entered)
        end
      end

      context 'with a view' do
        let(:topic) { Fabricate(:topic) }
        let!(:view) { View.create_for(topic, '127.0.0.1', user) }

        it "adds one to the topics entered" do
          User.update_view_counts
          user.reload
          user.topics_entered.should == 1
        end

        it "won't record a second view as a different topic" do
          View.create_for(topic, '127.0.0.1', user)
          User.update_view_counts
          user.reload
          user.topics_entered.should == 1
        end

      end
    end

    context 'posts_read_count' do
      context 'without any post timings' do
        it "doesn't increase the user's posts_read_count" do
          lambda { User.update_view_counts; user.reload }.should_not change(user, :posts_read_count)
        end
      end

      context 'with a post timing' do
        let!(:post) { Fabricate(:post) }
        let!(:post_timings) do
          PostTiming.record_timing(msecs: 1234, topic_id: post.topic_id, user_id: user.id, post_number: post.post_number)
        end

        it "increases posts_read_count" do
          User.update_view_counts
          user.reload
          user.posts_read_count.should == 1
        end
      end
    end
  end

  context '.enqueue_welcome_message' do
    let(:user) { Fabricate(:user) }

    it 'enqueues the system message' do
      Jobs.expects(:enqueue).with(:send_system_message, user_id: user.id, message_type: 'welcome_user')
      user.enqueue_welcome_message('welcome_user')
    end

    it "doesn't enqueue the system message when the site settings disable it" do
      SiteSetting.expects(:send_welcome_message?).returns(false)
      Jobs.expects(:enqueue).with(:send_system_message, user_id: user.id, message_type: 'welcome_user').never
      user.enqueue_welcome_message('welcome_user')
    end

  end

  describe '.approve' do
    let(:user) { Fabricate(:user) }
    let(:admin) { Fabricate(:admin) }

    it "generates a welcome message" do
      user.expects(:enqueue_welcome_message).with('welcome_approved')
      user.approve(admin)
    end

    context 'after approval' do
      before do
        user.approve(admin)
      end

      it 'marks the user as approved' do
        user.should be_approved
      end

      it 'has the admin as the approved by' do
        user.approved_by.should == admin
      end

      it 'has a value for approved_at' do
        user.approved_at.should be_present
      end
    end
  end


  describe 'bookmark' do
    before do
      @post = Fabricate(:post)
    end

    it "creates a bookmark with the true parameter" do
      lambda {
        PostAction.act(@post.user, @post, PostActionType.types[:bookmark])
      }.should change(PostAction, :count).by(1)
    end

    describe 'when removing a bookmark' do
      before do
        PostAction.act(@post.user, @post, PostActionType.types[:bookmark])
      end

      it 'reduces the bookmark count of the post' do
        active = PostAction.where(deleted_at: nil)
        lambda {
          PostAction.remove_act(@post.user, @post, PostActionType.types[:bookmark])
        }.should change(active, :count).by(-1)
      end
    end
  end

  describe 'change_username' do

    let(:user) { Fabricate(:user) }

    context 'success' do
      let(:new_username) { "#{user.username}1234" }

      before do
        @result = user.change_username(new_username)
      end

      it 'returns true' do
        @result.should be_true
      end

      it 'should change the username' do
        user.reload
        user.username.should == new_username
      end

      it 'should change the username_lower' do
        user.reload
        user.username_lower.should == new_username.downcase
      end
    end

    context 'failure' do
      let(:wrong_username) { "" }
      let(:username_before_change) { user.username }
      let(:username_lower_before_change) { user.username_lower }

      before do
        @result = user.change_username(wrong_username)
      end

      it 'returns false' do
        @result.should be_false
      end

      it 'should not change the username' do
        user.reload
        user.username.should == username_before_change
      end

      it 'should not change the username_lower' do
        user.reload
        user.username_lower.should == username_lower_before_change
      end
    end

  end

  describe 'delete posts' do
    before do
      @post1 = Fabricate(:post)
      @user = @post1.user
      @post2 = Fabricate(:post, topic: @post1.topic, user: @user)
      @post3 = Fabricate(:post, user: @user)
      @posts = [@post1, @post2, @post3]
      @guardian = Guardian.new(Fabricate(:admin))
    end

    it 'allows moderator to delete all posts' do
      @user.delete_all_posts!(@guardian)
      @posts.each do |p|
        p.reload
        if p
          p.topic.should be_nil
        else
          p.should be_nil
        end
      end
    end

    it 'does not allow non moderators to delete all posts' do
      invalid_guardian = Guardian.new(Fabricate(:user))

      expect do
        @user.delete_all_posts!(invalid_guardian)
      end.to raise_error Discourse::InvalidAccess

      @posts.each do |p|
        p.reload
        p.should be_present
        p.topic.should be_present
      end
    end
  end

  describe 'new' do

    subject { Fabricate.build(:user) }

    it { should be_valid }
    it { should_not be_admin }
    it { should_not be_active }
    it { should_not be_approved }
    its(:approved_at) { should be_blank }
    its(:approved_by_id) { should be_blank }
    its(:email_digests) { should be_true }
    its(:email_private_messages) { should be_true }
    its(:email_direct ) { should be_true }
    its(:time_read) { should == 0}

    # Default to digests after one week
    its(:digest_after_days) { should == 7 }

    context 'after_save' do
      before do
        subject.save
      end

      its(:email_tokens) { should be_present }
      its(:bio_cooked) { should be_present }
      its(:bio_summary) { should be_present }
      its(:topics_entered) { should == 0 }
      its(:posts_read_count) { should == 0 }
    end
  end

  describe "trust levels" do

    # NOTE be sure to use build to avoid db calls 
    let(:user) { Fabricate.build(:user, trust_level: TrustLevel.levels[:newuser]) }

    it "sets to the default trust level setting" do
      SiteSetting.expects(:default_trust_level).returns(TrustLevel.levels[:elder])
      User.new.trust_level.should == TrustLevel.levels[:elder]
    end

    describe 'has_trust_level?' do

      it "raises an error with an invalid level" do
        lambda { user.has_trust_level?(:wat) }.should raise_error
      end

      it "is true for your basic level" do
        user.has_trust_level?(:newuser).should be_true
      end

      it "is false for a higher level" do
        user.has_trust_level?(:regular).should be_false
      end

      it "is true if you exceed the level" do
        user.trust_level = TrustLevel.levels[:elder]
        user.has_trust_level?(:newuser).should be_true
      end

      it "is true for an admin even with a low trust level" do
        user.trust_level = TrustLevel.levels[:new]
        user.admin = true
        user.has_trust_level?(:elder).should be_true
      end

    end

    describe 'moderator' do
      it "isn't a moderator by default" do
        user.moderator?.should be_false
      end

      it "is a moderator if the user level is moderator" do
        user.moderator = true
        user.has_trust_level?(:elder).should be_true
      end

      it "is staff if the user is an admin" do
        user.admin = true
        user.staff?.should be_true
      end

    end


  end

  describe 'temporary_key' do

    let(:user) { Fabricate(:user) }
    let!(:temporary_key) { user.temporary_key}

    it 'has a temporary key' do
      temporary_key.should be_present
    end

    describe 'User#find_by_temporary_key' do

      it 'can be used to find the user' do
        User.find_by_temporary_key(temporary_key).should == user
      end

      it 'returns nil with an invalid key' do
        User.find_by_temporary_key('asdfasdf').should be_blank
      end

    end

  end

  describe 'email_hash' do
    before do
      @user = Fabricate(:user)
    end

    it 'should have a sane email hash' do
      @user.email_hash.should =~ /^[0-9a-f]{32}$/
    end

    it 'should use downcase email' do
      @user.email = "example@example.com"
      @user2 = Fabricate(:user)
      @user2.email = "ExAmPlE@eXaMpLe.com"

      @user.email_hash.should == @user2.email_hash
    end

    it 'should trim whitespace before hashing' do
      @user.email = "example@example.com"
      @user2 = Fabricate(:user)
      @user2.email = " example@example.com "

      @user.email_hash.should == @user2.email_hash
    end
  end

  describe 'name heuristics' do
    it 'is able to guess a decent username from an email' do
      User.suggest_username('bob@bob.com').should == 'bob'
    end

    it 'is able to guess a decent name from an email' do
      User.suggest_name('sam.saffron@gmail.com').should == 'Sam Saffron'
    end
  end

  describe 'username format' do
    it "should always be 3 chars or longer" do
      @user = Fabricate.build(:user)
      @user.username = 'ss'
      @user.save.should == false
    end

    it "should never end with a ." do
      @user = Fabricate.build(:user)
      @user.username = 'sam.'
      @user.save.should == false
    end

    it "should never contain spaces" do
      @user = Fabricate.build(:user)
      @user.username = 'sam s'
      @user.save.should == false
    end

    ['Bad One', 'Giraf%fe', 'Hello!', '@twitter', 'me@example.com', 'no.dots', 'purple.', '.bilbo', '_nope', 'sa$sy'].each do |bad_nickname|
      it "should not allow username '#{bad_nickname}'" do
        @user = Fabricate.build(:user)
        @user.username = bad_nickname
        @user.save.should == false
      end
    end
  end

  describe 'username uniqueness' do
    before do
      @user = Fabricate.build(:user)
      @user.save!
      @codinghorror = Fabricate.build(:coding_horror)
    end

    it "should not allow saving if username is reused" do
       @codinghorror.username = @user.username
       @codinghorror.save.should be_false
    end

    it "should not allow saving if username is reused in different casing" do
       @codinghorror.username = @user.username.upcase
       @codinghorror.save.should be_false
    end
  end

  context '.username_available?' do
    it "returns true for a username that is available" do
      User.username_available?('BruceWayne').should be_true
    end

    it 'returns false when a username is taken' do
      User.username_available?(Fabricate(:user).username).should be_false
    end
  end

  describe '.suggest_username' do

    it "doesn't raise an error on nil username" do
      User.suggest_username(nil).should be_nil
    end

    it 'corrects weird characters' do
      User.suggest_username("Darth%^Vader").should == "Darth_Vader"
    end

    it 'adds 1 to an existing username' do
      user = Fabricate(:user)
      User.suggest_username(user.username).should == "#{user.username}1"
    end

    it "adds numbers if it's too short" do
      User.suggest_username('a').should == 'a11'
    end

    it "has a special case for me and i emails" do
      User.suggest_username('me@eviltrout.com').should == 'eviltrout'
      User.suggest_username('i@eviltrout.com').should == 'eviltrout'
    end

    it "shortens very long suggestions" do
      User.suggest_username("myreallylongnameisrobinwardesquire").should == 'myreallylongnam'
    end

    it "makes room for the digit added if the username is too long" do
      User.create(username: 'myreallylongnam', email: 'fake@discourse.org')
      User.suggest_username("myreallylongnam").should == 'myreallylongna1'
    end

    it "removes leading character if it is not alphanumeric" do
      User.suggest_username("_myname").should == 'myname'
    end

    it "removes trailing characters if they are invalid" do
      User.suggest_username("myname!^$=").should == 'myname'
    end

    it "replace dots" do
      User.suggest_username("my.name").should == 'my_name'
    end

    it "remove leading dots" do
      User.suggest_username(".myname").should == 'myname'
    end

    it "remove trailing dots" do
      User.suggest_username("myname.").should == 'myname'
    end

    it 'should handle typical facebook usernames' do
      User.suggest_username('roger.nelson.3344913').should == 'roger_nelson_33'
    end
  end

  describe 'email_validator' do
    it 'should allow good emails' do
      user = Fabricate.build(:user, email: 'good@gmail.com')
      user.should be_valid
    end

    it 'should reject some emails based on the email_domains_blacklist site setting' do
      SiteSetting.stubs(:email_domains_blacklist).returns('mailinator.com')
      Fabricate.build(:user, email: 'notgood@mailinator.com').should_not be_valid
      Fabricate.build(:user, email: 'mailinator@gmail.com').should be_valid
    end

    it 'should reject some emails based on the email_domains_blacklist site setting' do
      SiteSetting.stubs(:email_domains_blacklist).returns('mailinator.com|trashmail.net')
      Fabricate.build(:user, email: 'notgood@mailinator.com').should_not be_valid
      Fabricate.build(:user, email: 'notgood@trashmail.net').should_not be_valid
      Fabricate.build(:user, email: 'mailinator.com@gmail.com').should be_valid
    end

    it 'should not reject partial matches' do
      SiteSetting.stubs(:email_domains_blacklist).returns('mail.com')
      Fabricate.build(:user, email: 'mailinator@gmail.com').should be_valid
    end

    it 'should reject some emails based on the email_domains_blacklist site setting ignoring case' do
      SiteSetting.stubs(:email_domains_blacklist).returns('trashmail.net')
      Fabricate.build(:user, email: 'notgood@TRASHMAIL.NET').should_not be_valid
    end

    it 'should not interpret a period as a wildcard' do
      SiteSetting.stubs(:email_domains_blacklist).returns('trashmail.net')
      Fabricate.build(:user, email: 'good@trashmailinet.com').should be_valid
    end

    it 'should not be used to validate existing records' do
      u = Fabricate(:user, email: 'in_before_blacklisted@fakemail.com')
      SiteSetting.stubs(:email_domains_blacklist).returns('fakemail.com')
      u.should be_valid
    end

    it 'should be used when email is being changed' do
      SiteSetting.stubs(:email_domains_blacklist).returns('mailinator.com')
      u = Fabricate(:user, email: 'good@gmail.com')
      u.email = 'nope@mailinator.com'
      u.should_not be_valid
    end

    it 'whitelist should reject some emails based on the email_domains_whitelist site setting' do
      SiteSetting.stubs(:email_domains_whitelist).returns('vaynermedia.com')
      Fabricate.build(:user, email: 'notgood@mailinator.com').should_not be_valid
      Fabricate.build(:user, email: 'sbauch@vaynermedia.com').should be_valid
    end

    it 'should reject some emails based on the email_domains_whitelist site setting when whitelisting multiple domains' do
      SiteSetting.stubs(:email_domains_whitelist).returns('vaynermedia.com|gmail.com')
      Fabricate.build(:user, email: 'notgood@mailinator.com').should_not be_valid
      Fabricate.build(:user, email: 'notgood@trashmail.net').should_not be_valid
      Fabricate.build(:user, email: 'mailinator.com@gmail.com').should be_valid
      Fabricate.build(:user, email: 'mailinator.com@vaynermedia.com').should be_valid
    end

    it 'should accept some emails based on the email_domains_whitelist site setting ignoring case' do
      SiteSetting.stubs(:email_domains_whitelist).returns('vaynermedia.com')
      Fabricate.build(:user, email: 'good@VAYNERMEDIA.COM').should be_valid
    end

    it 'email whitelist should not be used to validate existing records' do
      u = Fabricate(:user, email: 'in_before_whitelisted@fakemail.com')
      SiteSetting.stubs(:email_domains_blacklist).returns('vaynermedia.com')
      u.should be_valid
    end

    it 'email whitelist should be used when email is being changed' do
      SiteSetting.stubs(:email_domains_whitelist).returns('vaynermedia.com')
      u = Fabricate(:user, email: 'good@vaynermedia.com')
      u.email = 'nope@mailinator.com'
      u.should_not be_valid
    end
  end

  describe 'passwords' do
    before do
      @user = Fabricate.build(:user)
      @user.password = "ilovepasta"
      @user.save!
    end

    it "should have a valid password after the initial save" do
      @user.confirm_password?("ilovepasta").should be_true
    end

    it "should not have an active account after initial save" do
      @user.active.should be_false
    end
  end

  describe 'changing bio' do
    let(:user) { Fabricate(:user) }

    before do
      user.bio_raw = "**turtle power!**"
      user.save
      user.reload
    end

    it "should markdown the raw_bio and put it in cooked_bio" do
      user.bio_cooked.should == "<p><strong>turtle power!</strong></p>"
    end

  end

  describe "previous_visit_at" do
    let(:user) { Fabricate(:user) }

    before do
      SiteSetting.stubs(:active_user_rate_limit_secs).returns(0)
    end

    it "should be blank on creation" do
      user.previous_visit_at.should be_nil
    end

    describe "first time" do
      let!(:first_visit_date) { DateTime.now }

      before do
        DateTime.stubs(:now).returns(first_visit_date)
        user.update_last_seen!
      end

      it "should have no value" do
        user.previous_visit_at.should be_nil
      end

      describe "another call right after" do
        before do
          # A different time, to make sure it doesn't change
          DateTime.stubs(:now).returns(10.minutes.from_now)
          user.update_last_seen!
        end

        it "still has no value" do
          user.previous_visit_at.should be_nil
        end
      end

      describe "second visit" do
        let!(:second_visit_date) { 2.hours.from_now }

        before do
          DateTime.stubs(:now).returns(second_visit_date)
          user.update_last_seen!
        end

        it "should have the previous visit value" do
          user.previous_visit_at.should == first_visit_date
        end

        describe "third visit" do
          let!(:third_visit_date) { 5.hours.from_now }

          before do
            DateTime.stubs(:now).returns(third_visit_date)
            user.update_last_seen!
          end

          it "should have the second visit value" do
            user.previous_visit_at.should == second_visit_date
          end

        end

      end

    end

  end

  describe "last_seen_at" do
    let(:user) { Fabricate(:user) }

    it "should have a blank last seen on creation" do
      user.last_seen_at.should be_nil
    end

    it "should have 0 for days_visited" do
      user.days_visited.should == 0
    end

    describe 'with no previous values' do
      let!(:date) { DateTime.now }

      before do
        DateTime.stubs(:now).returns(date)
        user.update_last_seen!
      end

      it "updates last_seen_at" do
        user.last_seen_at.should == date
      end

      it "should have 0 for days_visited" do
        user.reload
        user.days_visited.should == 1
      end

      it "should log a user_visit with the date" do
        user.user_visits.first.visited_at.should == date.to_date
      end

      context "called twice" do

        before do
          DateTime.stubs(:now).returns(date)
          user.update_last_seen!
          user.update_last_seen!
          user.reload
        end

        it "doesn't increase days_visited twice" do
          user.days_visited.should == 1
        end

      end

      describe "after 3 days" do
        let!(:future_date) { 3.days.from_now }

        before do
          DateTime.stubs(:now).returns(future_date)
          user.update_last_seen!
        end

        it "should log a second visited_at record when we log an update later" do
          user.user_visits.count.should == 2
        end
      end

    end
  end

  describe '#create_for_email' do
    let(:subject) { User.create_for_email('walter.white@email.com') }
    it { should be_present }
    its(:username) { should == 'walter_white' }
    its(:name) { should == 'walter_white'}
    it { should_not be_active }
    its(:email) { should == 'walter.white@email.com' }
  end

  describe 'email_confirmed?' do
    let(:user) { Fabricate(:user) }

    context 'when email has not been confirmed yet' do
      it 'should return false' do
        user.email_confirmed?.should be_false
      end
    end

    context 'when email has been confirmed' do
      it 'should return true' do
        token = user.email_tokens.where(email: user.email).first
        EmailToken.confirm(token.token)
        user.email_confirmed?.should be_true
      end
    end

    context 'when user has no email tokens for some reason' do
      it 'should return false' do
        user.email_tokens.each {|t| t.destroy}
        user.reload
        user.email_confirmed?.should be_true
      end
    end
  end


  describe 'update_time_read!' do
    let(:user) { Fabricate(:user) }

    it 'makes no changes if nothing is cached' do
      $redis.expects(:get).with("user-last-seen:#{user.id}").returns(nil)
      user.update_time_read!
      user.reload
      user.time_read.should == 0
    end

    it 'makes a change if time read is below threshold' do
      $redis.expects(:get).with("user-last-seen:#{user.id}").returns(Time.now - 10.0)
      user.update_time_read!
      user.reload
      user.time_read.should == 10
    end

    it 'makes no change if time read is above threshold' do
      t = Time.now - 1 - User::MAX_TIME_READ_DIFF
      $redis.expects(:get).with("user-last-seen:#{user.id}").returns(t)
      user.update_time_read!
      user.reload
      user.time_read.should == 0
    end

  end

  describe '#readable_name' do
    context 'when name is missing' do
      it 'returns just the username' do
        Fabricate(:user, username: 'foo', name: nil).readable_name.should == 'foo'
      end
    end
    context 'when name and username are identical' do
      it 'returns just the username' do
        Fabricate(:user, username: 'foo', name: 'foo').readable_name.should == 'foo'
      end
    end
    context 'when name and username are not identical' do
      it 'returns the name and username' do
        Fabricate(:user, username: 'foo', name: 'Bar Baz').readable_name.should == 'Bar Baz (foo)'
      end
    end
  end

end
