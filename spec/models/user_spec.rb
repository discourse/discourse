require 'spec_helper'
require_dependency 'user'

describe User do

  it { should validate_presence_of :username }
  it { should validate_presence_of :email }

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

    it "enqueues a 'signup after approval' email" do
      Jobs.expects(:enqueue).with(
        :user_email, has_entries(type: :signup_after_approval)
      )
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
        @result.should == true
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
        @result.should == false
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

    describe 'change the case of my username' do
      let!(:myself) { Fabricate(:user, username: 'hansolo') }

      it 'should return true' do
        myself.change_username('HanSolo').should == true
      end

      it 'should change the username' do
        myself.change_username('HanSolo')
        myself.reload.username.should == 'HanSolo'
      end
    end

    describe 'allow custom minimum username length from site settings' do
      before do
        @custom_min = 2
        SiteSetting.min_username_length = @custom_min
      end

      it 'should allow a shorter username than default' do
        result = user.change_username('a' * @custom_min)
        result.should_not == false
      end

      it 'should not allow a shorter username than limit' do
        result = user.change_username('a' * (@custom_min - 1))
        result.should == false
      end

      it 'should not allow a longer username than limit' do
        result = user.change_username('a' * (User.username_length.end + 1))
        result.should == false
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
      expect(Post.where(id: @posts.map(&:id))).to be_empty
      @posts.each do |p|
        if p.post_number == 1
          expect(Topic.find_by(id: p.topic_id)).should == nil
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
    it { should_not be_approved }

    it "is properly initialized" do
      subject.approved_at.should be_blank
      subject.approved_by_id.should be_blank
      subject.email_private_messages.should == true
      subject.email_direct.should == true
    end

    context 'digest emails' do
      it 'defaults to digests every week' do
        subject.email_digests.should == true
        subject.digest_after_days.should == 7
      end

      it 'uses default_digest_email_frequency' do
        SiteSetting.stubs(:default_digest_email_frequency).returns(1)
        subject.email_digests.should == true
        subject.digest_after_days.should == 1
      end

      it 'disables digests by default if site setting says so' do
        SiteSetting.stubs(:default_digest_email_frequency).returns('')
        subject.email_digests.should == false
      end
    end

    context 'after_save' do
      before { subject.save }

      it "has an email token" do
        subject.email_tokens.should be_present
      end
    end

    it "downcases email addresses" do
      user = Fabricate.build(:user, email: 'Fancy.Caps.4.U@gmail.com')
      user.save
      user.reload.email.should == 'fancy.caps.4.u@gmail.com'
    end
  end

  describe 'ip address validation' do
    it 'validates ip_address for new users' do
      u = Fabricate.build(:user)
      AllowedIpAddressValidator.any_instance.expects(:validate_each).with(u, :ip_address, u.ip_address)
      u.valid?
    end

    it 'does not validate ip_address when updating an existing user' do
      u = Fabricate(:user)
      u.ip_address = '87.123.23.11'
      AllowedIpAddressValidator.any_instance.expects(:validate_each).never
      u.valid?
    end
  end

  describe "trust levels" do

    # NOTE be sure to use build to avoid db calls
    let(:user) { Fabricate.build(:user, trust_level: TrustLevel[0]) }

    it "sets to the default trust level setting" do
      SiteSetting.default_trust_level = TrustLevel[4]
      User.new.trust_level.should == TrustLevel[4]
    end

    describe 'has_trust_level?' do

      it "raises an error with an invalid level" do
        lambda { user.has_trust_level?(:wat) }.should raise_error
      end

      it "is true for your basic level" do
        user.has_trust_level?(TrustLevel[0]).should == true
      end

      it "is false for a higher level" do
        user.has_trust_level?(TrustLevel[2]).should == false
      end

      it "is true if you exceed the level" do
        user.trust_level = TrustLevel[4]
        user.has_trust_level?(TrustLevel[1]).should == true
      end

      it "is true for an admin even with a low trust level" do
        user.trust_level = TrustLevel[0]
        user.admin = true
        user.has_trust_level?(TrustLevel[1]).should == true
      end

    end

    describe 'moderator' do
      it "isn't a moderator by default" do
        user.moderator?.should == false
      end

      it "is a moderator if the user level is moderator" do
        user.moderator = true
        user.has_trust_level?(TrustLevel[4]).should == true
      end

      it "is staff if the user is an admin" do
        user.admin = true
        user.staff?.should == true
      end

    end


  end

  describe 'staff and regular users' do
    let(:user) { Fabricate.build(:user) }

    describe '#staff?' do
      subject { user.staff? }

      it { should == false }

      context 'for a moderator user' do
        before { user.moderator = true }

        it { should == true }
      end

      context 'for an admin user' do
        before { user.admin = true }

        it { should == true }
      end
    end

    describe '#regular?' do
      subject { user.regular? }

      it { should == true }

      context 'for a moderator user' do
        before { user.moderator = true }

        it { should == false }
      end

      context 'for an admin user' do
        before { user.admin = true }

        it { should == false }
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

  describe 'associated_accounts' do
    it 'should correctly find social associations' do
      user = Fabricate(:user)
      user.associated_accounts.should == I18n.t("user.no_accounts_associated")

      TwitterUserInfo.create(user_id: user.id, screen_name: "sam", twitter_user_id: 1)
      FacebookUserInfo.create(user_id: user.id, username: "sam", facebook_user_id: 1)
      GoogleUserInfo.create(user_id: user.id, email: "sam@sam.com", google_user_id: 1)
      GithubUserInfo.create(user_id: user.id, screen_name: "sam", github_user_id: 1)

      user.reload
      user.associated_accounts.should == "Twitter(sam), Facebook(sam), Google(sam@sam.com), Github(sam)"

    end
  end

  describe 'name heuristics' do
    it 'is able to guess a decent name from an email' do
      User.suggest_name('sam.saffron@gmail.com').should == 'Sam Saffron'
    end
  end

  describe 'username format' do
    it "should be #{SiteSetting.min_username_length} chars or longer" do
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
       @codinghorror.save.should == false
    end

    it "should not allow saving if username is reused in different casing" do
       @codinghorror.username = @user.username.upcase
       @codinghorror.save.should == false
    end
  end

  context '.username_available?' do
    it "returns true for a username that is available" do
      User.username_available?('BruceWayne').should == true
    end

    it 'returns false when a username is taken' do
      User.username_available?(Fabricate(:user).username).should == false
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
      @user = Fabricate.build(:user, active: false)
      @user.password = "ilovepasta"
      @user.save!
    end

    it "should have a valid password after the initial save" do
      @user.confirm_password?("ilovepasta").should == true
    end

    it "should not have an active account after initial save" do
      @user.active.should == false
    end
  end

  describe "previous_visit_at" do

    let(:user) { Fabricate(:user) }
    let!(:first_visit_date) { Time.zone.now }
    let!(:second_visit_date) { 2.hours.from_now }
    let!(:third_visit_date) { 5.hours.from_now }

    before do
      SiteSetting.stubs(:active_user_rate_limit_secs).returns(0)
      SiteSetting.stubs(:previous_visit_timeout_hours).returns(1)
    end

    it "should act correctly" do
      user.previous_visit_at.should == nil

      # first visit
      user.update_last_seen!(first_visit_date)
      user.previous_visit_at.should == nil

      # updated same time
      user.update_last_seen!(first_visit_date)
      user.reload
      user.previous_visit_at.should == nil

      # second visit
      user.update_last_seen!(second_visit_date)
      user.reload
      user.previous_visit_at.should be_within_one_second_of(first_visit_date)

      # third visit
      user.update_last_seen!(third_visit_date)
      user.reload
      user.previous_visit_at.should be_within_one_second_of(second_visit_date)
    end

  end

  describe "last_seen_at" do
    let(:user) { Fabricate(:user) }

    it "should have a blank last seen on creation" do
      user.last_seen_at.should == nil
    end

    it "should have 0 for days_visited" do
      user.user_stat.days_visited.should == 0
    end

    describe 'with no previous values' do
      let!(:date) { Time.zone.now }

      before do
        Timecop.freeze(date)
        user.update_last_seen!
      end

      after do
        Timecop.return
      end

      it "updates last_seen_at" do
        user.last_seen_at.should be_within_one_second_of(date)
      end

      it "should have 0 for days_visited" do
        user.reload
        user.user_stat.days_visited.should == 1
      end

      it "should log a user_visit with the date" do
        user.user_visits.first.visited_at.should == date.to_date
      end

      context "called twice" do

        before do
          Timecop.freeze(date)
          user.update_last_seen!
          user.update_last_seen!
          user.reload
        end

        after do
          Timecop.return
        end

        it "doesn't increase days_visited twice" do
          user.user_stat.days_visited.should == 1
        end

      end

      describe "after 3 days" do
        let!(:future_date) { 3.days.from_now }

        before do
          Timecop.freeze(future_date)
          user.update_last_seen!
        end

        after do
          Timecop.return
        end

        it "should log a second visited_at record when we log an update later" do
          user.user_visits.count.should == 2
        end
      end

    end
  end

  describe 'email_confirmed?' do
    let(:user) { Fabricate(:user) }

    context 'when email has not been confirmed yet' do
      it 'should return false' do
        user.email_confirmed?.should == false
      end
    end

    context 'when email has been confirmed' do
      it 'should return true' do
        token = user.email_tokens.find_by(email: user.email)
        EmailToken.confirm(token.token)
        user.email_confirmed?.should == true
      end
    end

    context 'when user has no email tokens for some reason' do
      it 'should return false' do
        user.email_tokens.each {|t| t.destroy}
        user.reload
        user.email_confirmed?.should == true
      end
    end
  end

  describe "flag_linked_posts_as_spam" do
    let(:user) { Fabricate(:user) }
    let!(:admin) { Fabricate(:admin) }
    let!(:post) { PostCreator.new(user, title: "this topic contains spam", raw: "this post has a link: http://discourse.org").create }
    let!(:another_post) { PostCreator.new(user, title: "this topic also contains spam", raw: "this post has a link: http://discourse.org/asdfa").create }
    let!(:post_without_link) { PostCreator.new(user, title: "this topic shouldn't be spam", raw: "this post has no links in it.").create }

    it "has flagged all the user's posts as spam" do
      user.flag_linked_posts_as_spam

      post.reload
      post.spam_count.should == 1

      another_post.reload
      another_post.spam_count.should == 1

      post_without_link.reload
      post_without_link.spam_count.should == 0

      # It doesn't raise an exception if called again
      user.flag_linked_posts_as_spam

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

  describe '.find_by_username_or_email' do
    it 'finds users' do
      bob = Fabricate(:user, username: 'bob', email: 'bob@example.com')
      found_user = User.find_by_username_or_email('Bob')
      expect(found_user).to eq bob

      found_user = User.find_by_username_or_email('bob@Example.com')
      expect(found_user).to eq bob

      found_user = User.find_by_username_or_email('Bob@Example.com')
      expect(found_user).to eq bob

      found_user = User.find_by_username_or_email('bob1')
      expect(found_user).should == nil

      found_user = User.find_by_email('bob@Example.com')
      expect(found_user).to eq bob

      found_user = User.find_by_email('BOB@Example.com')
      expect(found_user).to eq bob

      found_user = User.find_by_email('bob')
      expect(found_user).should == nil

      found_user = User.find_by_username('bOb')
      expect(found_user).to eq bob
    end

  end

  describe "#added_a_day_ago?" do
    context "when user is more than a day old" do
      subject(:user) { Fabricate(:user, created_at: Date.today - 2.days) }

      it "returns false" do
        expect(user).to_not be_added_a_day_ago
      end
    end

    context "is less than a day old" do
      subject(:user) { Fabricate(:user) }

      it "returns true" do
        expect(user).to be_added_a_day_ago
      end
    end
  end

  describe 'api keys' do
    let(:admin) { Fabricate(:admin) }
    let(:other_admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user) }

    describe '.generate_api_key' do

      it "generates an api key when none exists, and regenerates when it does" do
        expect(user.api_key).to be_blank

        # Generate a key
        api_key = user.generate_api_key(admin)
        expect(api_key.user).to eq(user)
        expect(api_key.key).to be_present
        expect(api_key.created_by).to eq(admin)

        user.reload
        expect(user.api_key).to eq(api_key)

        # Regenerate a key. Keeps the same record, updates the key
        new_key = user.generate_api_key(other_admin)
        expect(new_key.id).to eq(api_key.id)
        expect(new_key.key).to_not eq(api_key.key)
        expect(new_key.created_by).to eq(other_admin)
      end

    end

    describe '.revoke_api_key' do

      it "revokes an api key when exists" do
        expect(user.api_key).to be_blank

        # Revoke nothing does nothing
        user.revoke_api_key
        user.reload
        expect(user.api_key).to be_blank

        # When a key is present it is removed
        user.generate_api_key(admin)
        user.reload
        user.revoke_api_key
        user.reload
        expect(user.api_key).to be_blank
      end

    end

  end

  describe "posted too much in topic" do
    let!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }
    let!(:topic) { Fabricate(:post).topic }

    before do
      # To make testing easier, say 1 reply is too much
      SiteSetting.stubs(:newuser_max_replies_per_topic).returns(1)
    end

    context "for a user who didn't create the topic" do
      let!(:post) { Fabricate(:post, topic: topic, user: user) }

      it "does not return true for staff" do
        user.stubs(:staff?).returns(true)
        user.posted_too_much_in_topic?(topic.id).should == false
      end

      it "returns true when the user has posted too much" do
        user.posted_too_much_in_topic?(topic.id).should == true
      end

      context "with a reply" do
        before do
          PostCreator.new(Fabricate(:user), raw: 'whatever this is a raw post', topic_id: topic.id, reply_to_post_number: post.post_number).create
        end

        it "resets the `posted_too_much` threshold" do
          user.posted_too_much_in_topic?(topic.id).should == false
        end
      end
    end

    it "returns false for a user who created the topic" do
      topic_user = topic.user
      topic_user.trust_level = TrustLevel[0]
      topic.user.posted_too_much_in_topic?(topic.id).should == false
    end

  end

  describe "#find_email" do

    let(:user) { Fabricate(:user, email: "bob@example.com") }

    context "when email is exists in the email logs" do
      before { user.stubs(:last_sent_email_address).returns("bob@lastemail.com") }

      it "returns email from the logs" do
        expect(user.find_email).to eq("bob@lastemail.com")
      end
    end

    context "when email does not exist in the email logs" do
      before { user.stubs(:last_sent_email_address).returns(nil) }

      it "fetches the user's email" do
        expect(user.find_email).to eq(user.email)
      end
    end
  end

  describe "#gravatar_template" do

    it "returns a gravatar based template" do
      User.gravatar_template("em@il.com").should == "//www.gravatar.com/avatar/6dc2fde946483a1d8a84b89345a1b638.png?s={size}&r=pg&d=identicon"
    end

  end

  describe ".small_avatar_url" do

    let(:user) { build(:user, username: 'Sam') }

    it "returns a 45-pixel-wide avatar" do
      user.small_avatar_url.should == "//test.localhost/letter_avatar/sam/45/#{LetterAvatar::VERSION}.png"
    end

  end

  describe ".avatar_template_url" do

    let(:user) { build(:user, uploaded_avatar_id: 99, username: 'Sam') }

    it "returns a schemaless avatar template with correct id" do
      user.avatar_template_url.should == "//test.localhost/user_avatar/test.localhost/sam/{size}/99.png"
    end

    it "returns a schemaless cdn-based avatar template" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      user.avatar_template_url.should == "//my.cdn.com/user_avatar/test.localhost/sam/{size}/99.png"
    end

  end

  describe "update_posts_read!" do
    context "with a UserVisit record" do
      let!(:user) { Fabricate(:user) }
      let!(:now)  { Time.zone.now }
      before { user.update_last_seen!(now) }

      it "with existing UserVisit record, increments the posts_read value" do
        expect {
          user_visit = user.update_posts_read!(2)
          user_visit.posts_read.should == 2
        }.to_not change { UserVisit.count }
      end

      it "with no existing UserVisit record, creates a new UserVisit record and increments the posts_read count" do
        expect {
          user_visit = user.update_posts_read!(3, 5.days.ago)
          user_visit.posts_read.should == 3
        }.to change { UserVisit.count }.by(1)
      end
    end
  end

  describe "primary_group_id" do
    let!(:user) { Fabricate(:user) }

    it "has no primary_group_id by default" do
      user.primary_group_id.should == nil
    end

    context "when the user has a group" do
      let!(:group) { Fabricate(:group) }

      before do
        group.usernames = user.username
        group.save
        user.primary_group_id = group.id
        user.save
        user.reload
      end

      it "should allow us to use it as a primary group" do
        user.primary_group_id.should == group.id

        # If we remove the user from the group
        group.usernames = ""
        group.save

        # It should unset it from the primary_group_id
        user.reload
        user.primary_group_id.should == nil
      end
    end
  end

  describe "should_be_redirected_to_top" do
    let!(:user) { Fabricate(:user) }

    it "should be redirected to top when there is a reason to" do
      user.expects(:redirected_to_top_reason).returns("42")
      user.should_be_redirected_to_top.should == true
    end

    it "should not be redirected to top when there is no reason to" do
      user.expects(:redirected_to_top_reason).returns(nil)
      user.should_be_redirected_to_top.should == false
    end

  end

  describe ".redirected_to_top_reason" do
    let!(:user) { Fabricate(:user) }

    it "should have no reason when `SiteSetting.redirect_users_to_top_page` is disabled" do
      SiteSetting.expects(:redirect_users_to_top_page).returns(false)
      user.redirected_to_top_reason.should == nil
    end

    context "when `SiteSetting.redirect_users_to_top_page` is enabled" do
      before { SiteSetting.expects(:redirect_users_to_top_page).returns(true) }

      it "should have no reason when top is not in the `SiteSetting.top_menu`" do
        SiteSetting.expects(:top_menu).returns("latest")
        user.redirected_to_top_reason.should == nil
      end

      context "and when top is in the `SiteSetting.top_menu`" do
        before { SiteSetting.expects(:top_menu).returns("latest|top") }

        it "should have no reason when there aren't enough topics" do
          SiteSetting.expects(:has_enough_topics_to_redirect_to_top).returns(false)
          user.redirected_to_top_reason.should == nil
        end

        context "and when there are enough topics" do
          before { SiteSetting.expects(:has_enough_topics_to_redirect_to_top).returns(true) }

          describe "a new user" do
            before do
              user.stubs(:trust_level).returns(0)
              user.stubs(:last_seen_at).returns(5.minutes.ago)
            end

            it "should have a reason for the first visit" do
              user.expects(:last_redirected_to_top_at).returns(nil)
              user.expects(:update_last_redirected_to_top!).once

              user.redirected_to_top_reason.should == I18n.t('redirected_to_top_reasons.new_user')
            end

            it "should not have a reason for next visits" do
              user.expects(:last_redirected_to_top_at).returns(10.minutes.ago)
              user.expects(:update_last_redirected_to_top!).never

              user.redirected_to_top_reason.should == nil
            end
          end

          describe "an older user" do
            before { user.stubs(:trust_level).returns(1) }

            it "should have a reason when the user hasn't been seen in a month" do
              user.last_seen_at = 2.months.ago
              user.expects(:update_last_redirected_to_top!).once

              user.redirected_to_top_reason.should == I18n.t('redirected_to_top_reasons.not_seen_in_a_month')
            end
          end

        end

      end

    end

  end

  describe "automatic avatar creation" do
    it "sets a system avatar for new users" do
      SiteSetting.enable_system_avatars = true
      u = User.create!(username: "bob", email: "bob@bob.com")
      u.reload
      u.uploaded_avatar_id.should == nil
      u.avatar_template.should == "/letter_avatar/bob/{size}/#{LetterAvatar::VERSION}.png"
    end
  end

  describe "custom fields" do
    it "allows modification of custom fields" do
      user = Fabricate(:user)

      user.custom_fields["a"].should == nil

      user.custom_fields["bob"] = "marley"
      user.custom_fields["jack"] = "black"
      user.save

      user = User.find(user.id)

      user.custom_fields["bob"].should == "marley"
      user.custom_fields["jack"].should == "black"

      user.custom_fields.delete("bob")
      user.custom_fields["jack"] = "jill"

      user.save
      user = User.find(user.id)

      user.custom_fields.should == {"jack" => "jill"}
    end
  end

  describe "refresh_avatar" do
    it "picks gravatar if system avatar is picked and gravatar was just downloaded" do

      png = Base64.decode64("R0lGODlhAQABALMAAAAAAIAAAACAAICAAAAAgIAAgACAgMDAwICAgP8AAAD/AP//AAAA//8A/wD//wBiZCH5BAEAAA8ALAAAAAABAAEAAAQC8EUAOw==")
      FakeWeb.register_uri( :get,
                            "http://www.gravatar.com/avatar/d10ca8d11301c2f4993ac2279ce4b930.png?s=500&d=404",
                             body: png )

      user = User.create!(username: "bob", name: "bob", email: "a@a.com")
      user.reload

      SiteSetting.automatically_download_gravatars = true
      SiteSetting.enable_system_avatars = true

      user.refresh_avatar
      user.reload

      user.user_avatar.gravatar_upload_id.should == user.uploaded_avatar_id

      user.uploaded_avatar_id = nil
      user.save
      user.refresh_avatar

      user.reload
      user.uploaded_avatar_id.should == nil
    end
  end

  describe "#purge_inactive" do
    let!(:user) { Fabricate(:user) }
    let!(:inactive) { Fabricate(:user, active: false) }
    let!(:inactive_old) { Fabricate(:user, active: false, created_at: 1.month.ago) }

    it 'should only remove old, inactive users' do
      User.purge_inactive
      all_users = User.all
      all_users.include?(user).should == true
      all_users.include?(inactive).should == true
      all_users.include?(inactive_old).should == false
    end
  end

  describe "hash_passwords" do

    let(:too_long) { "x" * (User.max_password_length + 1) }

    def hash(password, salt)
      User.new.send(:hash_password, password, salt)
    end

    it "returns the same hash for the same password and salt" do
      hash('poutine', 'gravy').should == hash('poutine', 'gravy')
    end

    it "returns a different hash for the same salt and different password" do
      hash('poutine', 'gravy').should_not == hash('fries', 'gravy')
    end

    it "returns a different hash for the same password and different salt" do
      hash('poutine', 'gravy').should_not == hash('poutine', 'cheese')
    end

    it "raises an error when passwords are too long" do
      -> { hash(too_long, 'gravy') }.should raise_error
    end

  end

end
