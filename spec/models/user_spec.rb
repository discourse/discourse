require 'spec_helper'
require_dependency 'user'

describe User do

  it { is_expected.to validate_presence_of :username }
  it { is_expected.to validate_presence_of :email }

  describe '#count_by_signup_date' do
    before(:each) do
      User.destroy_all
      Timecop.freeze
      Fabricate(:user)
      Fabricate(:user, created_at: 1.day.ago)
      Fabricate(:user, created_at: 1.day.ago)
      Fabricate(:user, created_at: 2.days.ago)
      Fabricate(:user, created_at: 4.days.ago)
    end
    after(:each) { Timecop.return }
    let(:signups_by_day) { {1.day.ago.to_date => 2, 2.days.ago.to_date => 1, Time.now.utc.to_date => 1} }

    it 'collect closed interval signups' do
      expect(User.count_by_signup_date(2.days.ago, Time.now)).to include(signups_by_day)
      expect(User.count_by_signup_date(2.days.ago, Time.now)).not_to include({4.days.ago.to_date => 1})
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

    it "enqueues a 'signup after approval' email if must_approve_users is true" do
      SiteSetting.stubs(:must_approve_users).returns(true)
      Jobs.expects(:enqueue).with(
        :user_email, has_entries(type: :signup_after_approval)
      )
      user.approve(admin)
    end

    it "doesn't enqueue a 'signup after approval' email if must_approve_users is false" do
      SiteSetting.stubs(:must_approve_users).returns(false)
      Jobs.expects(:enqueue).never
      user.approve(admin)
    end

    context 'after approval' do
      before do
        user.approve(admin)
      end

      it 'marks the user as approved' do
        expect(user).to be_approved
      end

      it 'has the admin as the approved by' do
        expect(user.approved_by).to eq(admin)
      end

      it 'has a value for approved_at' do
        expect(user.approved_at).to be_present
      end
    end
  end


  describe 'bookmark' do
    before do
      @post = Fabricate(:post)
    end

    it "creates a bookmark with the true parameter" do
      expect {
        PostAction.act(@post.user, @post, PostActionType.types[:bookmark])
      }.to change(PostAction, :count).by(1)
    end

    describe 'when removing a bookmark' do
      before do
        PostAction.act(@post.user, @post, PostActionType.types[:bookmark])
      end

      it 'reduces the bookmark count of the post' do
        active = PostAction.where(deleted_at: nil)
        expect {
          PostAction.remove_act(@post.user, @post, PostActionType.types[:bookmark])
        }.to change(active, :count).by(-1)
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
      @queued_post = Fabricate(:queued_post, user: @user)
    end

    it 'allows moderator to delete all posts' do
      @user.delete_all_posts!(@guardian)
      expect(Post.where(id: @posts.map(&:id))).to be_empty
      expect(QueuedPost.where(user_id: @user.id).count).to eq(0)
      @posts.each do |p|
        if p.is_first_post?
          expect(Topic.find_by(id: p.topic_id)).to be_nil
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
        expect(p).to be_present
        expect(p.topic).to be_present
      end
    end
  end

  describe 'new' do

    subject { Fabricate.build(:user) }

    it { is_expected.to be_valid }
    it { is_expected.not_to be_admin }
    it { is_expected.not_to be_approved }

    it "is properly initialized" do
      expect(subject.approved_at).to be_blank
      expect(subject.approved_by_id).to be_blank
      expect(subject.email_private_messages).to eq(true)
      expect(subject.email_direct).to eq(true)
    end

    context 'after_save' do
      before { subject.save }

      it "has an email token" do
        expect(subject.email_tokens).to be_present
      end
    end

    it "downcases email addresses" do
      user = Fabricate.build(:user, email: 'Fancy.Caps.4.U@gmail.com')
      user.valid?
      expect(user.email).to eq('fancy.caps.4.u@gmail.com')
    end

    it "strips whitespace from email addresses" do
      user = Fabricate.build(:user, email: ' example@gmail.com ')
      user.valid?
      expect(user.email).to eq('example@gmail.com')
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
      expect(User.new.trust_level).to eq(TrustLevel[4])
    end

    describe 'has_trust_level?' do

      it "raises an error with an invalid level" do
        expect { user.has_trust_level?(:wat) }.to raise_error
      end

      it "is true for your basic level" do
        expect(user.has_trust_level?(TrustLevel[0])).to eq(true)
      end

      it "is false for a higher level" do
        expect(user.has_trust_level?(TrustLevel[2])).to eq(false)
      end

      it "is true if you exceed the level" do
        user.trust_level = TrustLevel[4]
        expect(user.has_trust_level?(TrustLevel[1])).to eq(true)
      end

      it "is true for an admin even with a low trust level" do
        user.trust_level = TrustLevel[0]
        user.admin = true
        expect(user.has_trust_level?(TrustLevel[1])).to eq(true)
      end

    end

    describe 'moderator' do
      it "isn't a moderator by default" do
        expect(user.moderator?).to eq(false)
      end

      it "is a moderator if the user level is moderator" do
        user.moderator = true
        expect(user.has_trust_level?(TrustLevel[4])).to eq(true)
      end

      it "is staff if the user is an admin" do
        user.admin = true
        expect(user.staff?).to eq(true)
      end

    end


  end

  describe 'staff and regular users' do
    let(:user) { Fabricate.build(:user) }

    describe '#staff?' do
      subject { user.staff? }

      it { is_expected.to eq(false) }

      context 'for a moderator user' do
        before { user.moderator = true }

        it { is_expected.to eq(true) }
      end

      context 'for an admin user' do
        before { user.admin = true }

        it { is_expected.to eq(true) }
      end
    end

    describe '#regular?' do
      subject { user.regular? }

      it { is_expected.to eq(true) }

      context 'for a moderator user' do
        before { user.moderator = true }

        it { is_expected.to eq(false) }
      end

      context 'for an admin user' do
        before { user.admin = true }

        it { is_expected.to eq(false) }
      end
    end
  end

  describe 'email_hash' do
    before do
      @user = Fabricate(:user)
    end

    it 'should have a sane email hash' do
      expect(@user.email_hash).to match(/^[0-9a-f]{32}$/)
    end

    it 'should use downcase email' do
      @user.email = "example@example.com"
      @user2 = Fabricate(:user)
      @user2.email = "ExAmPlE@eXaMpLe.com"

      expect(@user.email_hash).to eq(@user2.email_hash)
    end

    it 'should trim whitespace before hashing' do
      @user.email = "example@example.com"
      @user2 = Fabricate(:user)
      @user2.email = " example@example.com "

      expect(@user.email_hash).to eq(@user2.email_hash)
    end
  end

  describe 'associated_accounts' do
    it 'should correctly find social associations' do
      user = Fabricate(:user)
      expect(user.associated_accounts).to eq(I18n.t("user.no_accounts_associated"))

      TwitterUserInfo.create(user_id: user.id, screen_name: "sam", twitter_user_id: 1)
      FacebookUserInfo.create(user_id: user.id, username: "sam", facebook_user_id: 1)
      GoogleUserInfo.create(user_id: user.id, email: "sam@sam.com", google_user_id: 1)
      GithubUserInfo.create(user_id: user.id, screen_name: "sam", github_user_id: 1)

      user.reload
      expect(user.associated_accounts).to eq("Twitter(sam), Facebook(sam), Google(sam@sam.com), Github(sam)")

    end
  end

  describe 'name heuristics' do
    it 'is able to guess a decent name from an email' do
      expect(User.suggest_name('sam.saffron@gmail.com')).to eq('Sam Saffron')
    end
  end

  describe 'username format' do
    def assert_bad(username)
      user = Fabricate.build(:user)
      user.username = username
      expect(user.valid?).to eq(false)
    end

    def assert_good(username)
      user = Fabricate.build(:user)
      user.username = username
      expect(user.valid?).to eq(true)
    end

    it "should be SiteSetting.min_username_length chars or longer" do
      SiteSetting.min_username_length = 5
      assert_bad("abcd")
      assert_good("abcde")
    end

    %w{ first.last
        first first-last
        _name first_last
        mc.hammer_nose
        UPPERCASE
        sgif
    }.each do |username|
      it "allows #{username}" do
        assert_good(username)
      end
    end

    %w{
      traildot.
      has\ space
      double__underscore
      with%symbol
      Exclamation!
      @twitter
      my@email.com
      .tester
      sa$sy
      sam.json
      sam.xml
      sam.html
      sam.htm
      sam.js
      sam.woff
      sam.Png
      sam.gif
    }.each do |username|
      it "disallows #{username}" do
        assert_bad(username)
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
       expect(@codinghorror.save).to eq(false)
    end

    it "should not allow saving if username is reused in different casing" do
       @codinghorror.username = @user.username.upcase
       expect(@codinghorror.save).to eq(false)
    end
  end

  context '.username_available?' do
    it "returns true for a username that is available" do
      expect(User.username_available?('BruceWayne')).to eq(true)
    end

    it 'returns false when a username is taken' do
      expect(User.username_available?(Fabricate(:user).username)).to eq(false)
    end
  end

  describe 'email_validator' do
    it 'should allow good emails' do
      user = Fabricate.build(:user, email: 'good@gmail.com')
      expect(user).to be_valid
    end

    it 'should reject some emails based on the email_domains_blacklist site setting' do
      SiteSetting.stubs(:email_domains_blacklist).returns('mailinator.com')
      expect(Fabricate.build(:user, email: 'notgood@mailinator.com')).not_to be_valid
      expect(Fabricate.build(:user, email: 'mailinator@gmail.com')).to be_valid
    end

    it 'should reject some emails based on the email_domains_blacklist site setting' do
      SiteSetting.stubs(:email_domains_blacklist).returns('mailinator.com|trashmail.net')
      expect(Fabricate.build(:user, email: 'notgood@mailinator.com')).not_to be_valid
      expect(Fabricate.build(:user, email: 'notgood@trashmail.net')).not_to be_valid
      expect(Fabricate.build(:user, email: 'mailinator.com@gmail.com')).to be_valid
    end

    it 'should not reject partial matches' do
      SiteSetting.stubs(:email_domains_blacklist).returns('mail.com')
      expect(Fabricate.build(:user, email: 'mailinator@gmail.com')).to be_valid
    end

    it 'should reject some emails based on the email_domains_blacklist site setting ignoring case' do
      SiteSetting.stubs(:email_domains_blacklist).returns('trashmail.net')
      expect(Fabricate.build(:user, email: 'notgood@TRASHMAIL.NET')).not_to be_valid
    end

    it 'should reject emails based on the email_domains_blacklist site setting matching subdomain' do
      SiteSetting.stubs(:email_domains_blacklist).returns('domain.com')
      expect(Fabricate.build(:user, email: 'notgood@sub.domain.com')).not_to be_valid
    end

    it 'blacklist should not reject developer emails' do
      Rails.configuration.stubs(:developer_emails).returns('developer@discourse.org')
      SiteSetting.stubs(:email_domains_blacklist).returns('discourse.org')
      expect(Fabricate.build(:user, email: 'developer@discourse.org')).to be_valid
    end

    it 'should not interpret a period as a wildcard' do
      SiteSetting.stubs(:email_domains_blacklist).returns('trashmail.net')
      expect(Fabricate.build(:user, email: 'good@trashmailinet.com')).to be_valid
    end

    it 'should not be used to validate existing records' do
      u = Fabricate(:user, email: 'in_before_blacklisted@fakemail.com')
      SiteSetting.stubs(:email_domains_blacklist).returns('fakemail.com')
      expect(u).to be_valid
    end

    it 'should be used when email is being changed' do
      SiteSetting.stubs(:email_domains_blacklist).returns('mailinator.com')
      u = Fabricate(:user, email: 'good@gmail.com')
      u.email = 'nope@mailinator.com'
      expect(u).not_to be_valid
    end

    it 'whitelist should reject some emails based on the email_domains_whitelist site setting' do
      SiteSetting.stubs(:email_domains_whitelist).returns('vaynermedia.com')
      expect(Fabricate.build(:user, email: 'notgood@mailinator.com')).not_to be_valid
      expect(Fabricate.build(:user, email: 'sbauch@vaynermedia.com')).to be_valid
    end

    it 'should reject some emails based on the email_domains_whitelist site setting when whitelisting multiple domains' do
      SiteSetting.stubs(:email_domains_whitelist).returns('vaynermedia.com|gmail.com')
      expect(Fabricate.build(:user, email: 'notgood@mailinator.com')).not_to be_valid
      expect(Fabricate.build(:user, email: 'notgood@trashmail.net')).not_to be_valid
      expect(Fabricate.build(:user, email: 'mailinator.com@gmail.com')).to be_valid
      expect(Fabricate.build(:user, email: 'mailinator.com@vaynermedia.com')).to be_valid
    end

    it 'should accept some emails based on the email_domains_whitelist site setting ignoring case' do
      SiteSetting.stubs(:email_domains_whitelist).returns('vaynermedia.com')
      expect(Fabricate.build(:user, email: 'good@VAYNERMEDIA.COM')).to be_valid
    end

    it 'whitelist should accept developer emails' do
      Rails.configuration.stubs(:developer_emails).returns('developer@discourse.org')
      SiteSetting.stubs(:email_domains_whitelist).returns('awesome.org')
      expect(Fabricate.build(:user, email: 'developer@discourse.org')).to be_valid
    end

    it 'email whitelist should not be used to validate existing records' do
      u = Fabricate(:user, email: 'in_before_whitelisted@fakemail.com')
      SiteSetting.stubs(:email_domains_blacklist).returns('vaynermedia.com')
      expect(u).to be_valid
    end

    it 'email whitelist should be used when email is being changed' do
      SiteSetting.stubs(:email_domains_whitelist).returns('vaynermedia.com')
      u = Fabricate(:user, email: 'good@vaynermedia.com')
      u.email = 'nope@mailinator.com'
      expect(u).not_to be_valid
    end
  end

  describe 'passwords' do

    it "should not have an active account with a good password" do
      @user = Fabricate.build(:user, active: false)
      @user.password = "ilovepasta"
      @user.save!

      @user.auth_token = SecureRandom.hex(16)
      @user.save!

      expect(@user.active).to eq(false)
      expect(@user.confirm_password?("ilovepasta")).to eq(true)


      email_token = @user.email_tokens.create(email: 'pasta@delicious.com')

      old_token = @user.auth_token
      @user.password = "passwordT"
      @user.save!

      # must expire old token on password change
      expect(@user.auth_token).to_not eq(old_token)

      email_token.reload
      expect(email_token.expired).to eq(true)
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
      expect(user.previous_visit_at).to eq(nil)

      # first visit
      user.update_last_seen!(first_visit_date)
      expect(user.previous_visit_at).to eq(nil)

      # updated same time
      user.update_last_seen!(first_visit_date)
      user.reload
      expect(user.previous_visit_at).to eq(nil)

      # second visit
      user.update_last_seen!(second_visit_date)
      user.reload
      expect(user.previous_visit_at).to be_within_one_second_of(first_visit_date)

      # third visit
      user.update_last_seen!(third_visit_date)
      user.reload
      expect(user.previous_visit_at).to be_within_one_second_of(second_visit_date)
    end

  end

  describe "last_seen_at" do
    let(:user) { Fabricate(:user) }

    it "should have a blank last seen on creation" do
      expect(user.last_seen_at).to eq(nil)
    end

    it "should have 0 for days_visited" do
      expect(user.user_stat.days_visited).to eq(0)
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
        expect(user.last_seen_at).to be_within_one_second_of(date)
      end

      it "should have 0 for days_visited" do
        user.reload
        expect(user.user_stat.days_visited).to eq(1)
      end

      it "should log a user_visit with the date" do
        expect(user.user_visits.first.visited_at).to eq(date.to_date)
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
          expect(user.user_stat.days_visited).to eq(1)
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
          expect(user.user_visits.count).to eq(2)
        end
      end

    end
  end

  describe 'email_confirmed?' do
    let(:user) { Fabricate(:user) }

    context 'when email has not been confirmed yet' do
      it 'should return false' do
        expect(user.email_confirmed?).to eq(false)
      end
    end

    context 'when email has been confirmed' do
      it 'should return true' do
        token = user.email_tokens.find_by(email: user.email)
        EmailToken.confirm(token.token)
        expect(user.email_confirmed?).to eq(true)
      end
    end

    context 'when user has no email tokens for some reason' do
      it 'should return false' do
        user.email_tokens.each {|t| t.destroy}
        user.reload
        expect(user.email_confirmed?).to eq(true)
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
      expect(post.spam_count).to eq(1)

      another_post.reload
      expect(another_post.spam_count).to eq(1)

      post_without_link.reload
      expect(post_without_link.spam_count).to eq(0)

      # It doesn't raise an exception if called again
      user.flag_linked_posts_as_spam

    end

  end

  describe '#readable_name' do
    context 'when name is missing' do
      it 'returns just the username' do
        expect(Fabricate(:user, username: 'foo', name: nil).readable_name).to eq('foo')
      end
    end
    context 'when name and username are identical' do
      it 'returns just the username' do
        expect(Fabricate(:user, username: 'foo', name: 'foo').readable_name).to eq('foo')
      end
    end
    context 'when name and username are not identical' do
      it 'returns the name and username' do
        expect(Fabricate(:user, username: 'foo', name: 'Bar Baz').readable_name).to eq('Bar Baz (foo)')
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
      expect(found_user).to be_nil

      found_user = User.find_by_email('bob@Example.com')
      expect(found_user).to eq bob

      found_user = User.find_by_email('BOB@Example.com')
      expect(found_user).to eq bob

      found_user = User.find_by_email('bob')
      expect(found_user).to be_nil

      found_user = User.find_by_username('bOb')
      expect(found_user).to eq bob
    end

  end

  describe "#first_day_user?" do

    def test_user?(opts={})
      Fabricate.build(:user, {created_at: Time.now}.merge(opts)).first_day_user?
    end

    it "works" do
      expect(test_user?).to eq(true)
      expect(test_user?(moderator: true)).to eq(false)
      expect(test_user?(trust_level: TrustLevel[2])).to eq(false)
      expect(test_user?(created_at: 2.days.ago)).to eq(false)
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
        expect(user.posted_too_much_in_topic?(topic.id)).to eq(false)
      end

      it "returns true when the user has posted too much" do
        expect(user.posted_too_much_in_topic?(topic.id)).to eq(true)
      end

      context "with a reply" do
        before do
          PostCreator.new(Fabricate(:user), raw: 'whatever this is a raw post', topic_id: topic.id, reply_to_post_number: post.post_number).create
        end

        it "resets the `posted_too_much` threshold" do
          expect(user.posted_too_much_in_topic?(topic.id)).to eq(false)
        end
      end
    end

    it "returns false for a user who created the topic" do
      topic_user = topic.user
      topic_user.trust_level = TrustLevel[0]
      expect(topic.user.posted_too_much_in_topic?(topic.id)).to eq(false)
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
      expect(User.gravatar_template("em@il.com")).to eq("//www.gravatar.com/avatar/6dc2fde946483a1d8a84b89345a1b638.png?s={size}&r=pg&d=identicon")
    end

  end

  describe ".small_avatar_url" do

    let(:user) { build(:user, username: 'Sam') }

    it "returns a 45-pixel-wide avatar" do
      SiteSetting.external_system_avatars_enabled = false
      expect(user.small_avatar_url).to eq("//test.localhost/letter_avatar/sam/45/#{LetterAvatar.version}.png")

      SiteSetting.external_system_avatars_enabled = true
      expect(user.small_avatar_url).to eq("https://avatars.discourse.org/letter/s/5f9b8f/45.png")
    end

  end

  describe ".avatar_template_url" do

    let(:user) { build(:user, uploaded_avatar_id: 99, username: 'Sam') }

    it "returns a schemaless avatar template with correct id" do
      expect(user.avatar_template_url).to eq("//test.localhost/user_avatar/test.localhost/sam/{size}/99_#{OptimizedImage::VERSION}.png")
    end

    it "returns a schemaless cdn-based avatar template" do
      Rails.configuration.action_controller.stubs(:asset_host).returns("http://my.cdn.com")
      expect(user.avatar_template_url).to eq("//my.cdn.com/user_avatar/test.localhost/sam/{size}/99_#{OptimizedImage::VERSION}.png")
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
          expect(user_visit.posts_read).to eq(2)
        }.to_not change { UserVisit.count }
      end

      it "with no existing UserVisit record, creates a new UserVisit record and increments the posts_read count" do
        expect {
          user_visit = user.update_posts_read!(3, at: 5.days.ago)
          expect(user_visit.posts_read).to eq(3)
        }.to change { UserVisit.count }.by(1)
      end
    end
  end

  describe "primary_group_id" do
    let!(:user) { Fabricate(:user) }

    it "has no primary_group_id by default" do
      expect(user.primary_group_id).to eq(nil)
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
        expect(user.primary_group_id).to eq(group.id)

        # If we remove the user from the group
        group.usernames = ""
        group.save

        # It should unset it from the primary_group_id
        user.reload
        expect(user.primary_group_id).to eq(nil)
      end
    end
  end

  context "group management" do
    let!(:user) { Fabricate(:user) }

    it "by default has no managed groups" do
      expect(user.managed_groups).to be_empty
    end

    it "can manage multiple groups" do
      3.times do |i|
        g = Fabricate(:group, name: "group_#{i}")
        g.appoint_manager(user)
      end
      expect(user.managed_groups.count).to eq(3)
    end
  end

  describe "should_be_redirected_to_top" do
    let!(:user) { Fabricate(:user) }

    it "should be redirected to top when there is a reason to" do
      user.expects(:redirected_to_top).returns({ reason: "42" })
      expect(user.should_be_redirected_to_top).to eq(true)
    end

    it "should not be redirected to top when there is no reason to" do
      user.expects(:redirected_to_top).returns(nil)
      expect(user.should_be_redirected_to_top).to eq(false)
    end

  end

  describe ".redirected_to_top" do
    let!(:user) { Fabricate(:user) }

    it "should have no reason when `SiteSetting.redirect_users_to_top_page` is disabled" do
      SiteSetting.expects(:redirect_users_to_top_page).returns(false)
      expect(user.redirected_to_top).to eq(nil)
    end

    context "when `SiteSetting.redirect_users_to_top_page` is enabled" do
      before { SiteSetting.expects(:redirect_users_to_top_page).returns(true) }

      it "should have no reason when top is not in the `SiteSetting.top_menu`" do
        SiteSetting.expects(:top_menu).returns("latest")
        expect(user.redirected_to_top).to eq(nil)
      end

      context "and when top is in the `SiteSetting.top_menu`" do
        before { SiteSetting.expects(:top_menu).returns("latest|top") }

        it "should have no reason when there are not enough topics" do
          SiteSetting.expects(:min_redirected_to_top_period).returns(nil)
          expect(user.redirected_to_top).to eq(nil)
        end

        context "and there are enough topics" do

          before { SiteSetting.expects(:min_redirected_to_top_period).returns(:monthly) }

          describe "a new user" do
            before do
              user.stubs(:trust_level).returns(0)
              user.stubs(:last_seen_at).returns(5.minutes.ago)
            end

            it "should have a reason for the first visit" do
              user.expects(:last_redirected_to_top_at).returns(nil)
              user.expects(:update_last_redirected_to_top!).once

              expect(user.redirected_to_top).to eq({
                reason: I18n.t('redirected_to_top_reasons.new_user'),
                period: :monthly
              })
            end

            it "should not have a reason for next visits" do
              user.expects(:last_redirected_to_top_at).returns(10.minutes.ago)
              user.expects(:update_last_redirected_to_top!).never

              expect(user.redirected_to_top).to eq(nil)
            end
          end

          describe "an older user" do
            before { user.stubs(:trust_level).returns(1) }

            it "should have a reason when the user hasn't been seen in a month" do
              user.last_seen_at = 2.months.ago
              user.expects(:update_last_redirected_to_top!).once

              expect(user.redirected_to_top).to eq({
                reason: I18n.t('redirected_to_top_reasons.not_seen_in_a_month'),
                period: :monthly
              })
            end

          end

        end

      end

    end

  end

  describe "automatic avatar creation" do
    it "sets a system avatar for new users" do
      SiteSetting.external_system_avatars_enabled = false

      u = User.create!(username: "bob", email: "bob@bob.com")
      u.reload
      expect(u.uploaded_avatar_id).to eq(nil)
      expect(u.avatar_template).to eq("/letter_avatar/bob/{size}/#{LetterAvatar.version}.png")
    end
  end

  describe "custom fields" do
    it "allows modification of custom fields" do
      user = Fabricate(:user)

      expect(user.custom_fields["a"]).to eq(nil)

      user.custom_fields["bob"] = "marley"
      user.custom_fields["jack"] = "black"
      user.save

      user = User.find(user.id)

      expect(user.custom_fields["bob"]).to eq("marley")
      expect(user.custom_fields["jack"]).to eq("black")

      user.custom_fields.delete("bob")
      user.custom_fields["jack"] = "jill"

      user.save
      user = User.find(user.id)

      expect(user.custom_fields).to eq({"jack" => "jill"})
    end
  end

  describe "refresh_avatar" do
    it "enqueues the update_gravatar job when automatically downloading gravatars" do
      SiteSetting.automatically_download_gravatars = true

      user = Fabricate(:user)

      Jobs.expects(:enqueue).with(:update_gravatar, anything)

      user.refresh_avatar
    end
  end

  describe "#purge_unactivated" do
    let!(:user) { Fabricate(:user) }
    let!(:inactive) { Fabricate(:user, active: false) }
    let!(:inactive_old) { Fabricate(:user, active: false, created_at: 1.month.ago) }

    it 'should only remove old, unactivated users' do
      User.purge_unactivated
      all_users = User.all
      expect(all_users.include?(user)).to eq(true)
      expect(all_users.include?(inactive)).to eq(true)
      expect(all_users.include?(inactive_old)).to eq(false)
    end
  end

  describe "hash_passwords" do

    let(:too_long) { "x" * (User.max_password_length + 1) }

    def hash(password, salt)
      User.new.send(:hash_password, password, salt)
    end

    it "returns the same hash for the same password and salt" do
      expect(hash('poutine', 'gravy')).to eq(hash('poutine', 'gravy'))
    end

    it "returns a different hash for the same salt and different password" do
      expect(hash('poutine', 'gravy')).not_to eq(hash('fries', 'gravy'))
    end

    it "returns a different hash for the same password and different salt" do
      expect(hash('poutine', 'gravy')).not_to eq(hash('poutine', 'cheese'))
    end

    it "raises an error when passwords are too long" do
      expect { hash(too_long, 'gravy') }.to raise_error
    end

  end

  describe "automatic group membership" do

    it "is automatically added to a group when the email matches" do
      group = Fabricate(:group, automatic_membership_email_domains: "bar.com|wat.com")
      user = Fabricate(:user, email: "foo@bar.com")
      group.reload
      expect(group.users.include?(user)).to eq(true)
    end

  end

  describe "number_of_flags_given" do

    let(:user) { Fabricate(:user) }
    let(:moderator) { Fabricate(:moderator) }

    it "doesn't count disagreed flags" do
      post_agreed = Fabricate(:post)
      PostAction.act(user, post_agreed, PostActionType.types[:off_topic])
      PostAction.agree_flags!(post_agreed, moderator)

      post_deferred = Fabricate(:post)
      PostAction.act(user, post_deferred, PostActionType.types[:inappropriate])
      PostAction.defer_flags!(post_deferred, moderator)

      post_disagreed = Fabricate(:post)
      PostAction.act(user, post_disagreed, PostActionType.types[:spam])
      PostAction.clear_flags!(post_disagreed, moderator)

      expect(user.number_of_flags_given).to eq(2)
    end

  end

  describe "number_of_deleted_posts" do

    let(:user) { Fabricate(:user, id: 2) }
    let(:moderator) { Fabricate(:moderator) }

    it "counts all the posts" do
      # at least 1 "unchanged" post
      Fabricate(:post, user: user)

      post_deleted_by_moderator = Fabricate(:post, user: user)
      PostDestroyer.new(moderator, post_deleted_by_moderator).destroy

      post_deleted_by_user = Fabricate(:post, user: user, post_number: 2)
      PostDestroyer.new(user, post_deleted_by_user).destroy

      # fake stub deletion
      post_deleted_by_user.update_columns(updated_at: 2.days.ago)
      PostDestroyer.destroy_stubs

      expect(user.number_of_deleted_posts).to eq(2)
    end

  end

  describe "new_user?" do
    it "correctly detects new user" do
      user = User.new(created_at: Time.now, trust_level: TrustLevel[0])

      expect(user.new_user?).to eq(true)

      user.trust_level = TrustLevel[1]

      expect(user.new_user?).to eq(true)

      user.trust_level = TrustLevel[2]

      expect(user.new_user?).to eq(false)

      user.trust_level = TrustLevel[0]
      user.moderator = true

      expect(user.new_user?).to eq(false)
    end
  end

  context "when user preferences are overriden" do

    before do
      SiteSetting.stubs(:default_email_digest_frequency).returns(1) # daily
      SiteSetting.stubs(:default_email_private_messages).returns(false)
      SiteSetting.stubs(:default_email_direct).returns(false)
      SiteSetting.stubs(:default_email_mailing_list_mode).returns(true)
      SiteSetting.stubs(:default_email_always).returns(true)

      SiteSetting.stubs(:default_other_new_topic_duration_minutes).returns(-1) # not viewed
      SiteSetting.stubs(:default_other_auto_track_topics_after_msecs).returns(0) # immediately
      SiteSetting.stubs(:default_other_external_links_in_new_tab).returns(true)
      SiteSetting.stubs(:default_other_enable_quoting).returns(false)
      SiteSetting.stubs(:default_other_dynamic_favicon).returns(true)
      SiteSetting.stubs(:default_other_disable_jump_reply).returns(true)
      SiteSetting.stubs(:default_other_edit_history_public).returns(true)

      SiteSetting.stubs(:default_categories_watching).returns("1")
      SiteSetting.stubs(:default_categories_tracking).returns("2")
      SiteSetting.stubs(:default_categories_muted).returns("3")
    end

    it "has overriden preferences" do
      user = Fabricate(:user)

      expect(user.digest_after_days).to eq(1)
      expect(user.email_private_messages).to eq(false)
      expect(user.email_direct).to eq(false)
      expect(user.mailing_list_mode).to eq(true)
      expect(user.email_always).to eq(true)

      expect(user.new_topic_duration_minutes).to eq(-1)
      expect(user.auto_track_topics_after_msecs).to eq(0)
      expect(user.external_links_in_new_tab).to eq(true)
      expect(user.enable_quoting).to eq(false)
      expect(user.dynamic_favicon).to eq(true)
      expect(user.disable_jump_reply).to eq(true)
      expect(user.edit_history_public).to eq(true)

      expect(CategoryUser.lookup(user, :watching).pluck(:category_id)).to eq([1])
      expect(CategoryUser.lookup(user, :tracking).pluck(:category_id)).to eq([2])
      expect(CategoryUser.lookup(user, :muted).pluck(:category_id)).to eq([3])
    end

  end

end
