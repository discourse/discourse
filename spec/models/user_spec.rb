# frozen_string_literal: true

require 'rails_helper'

describe User do
  fab!(:group) { Fabricate(:group) }

  let(:user) { Fabricate(:user, last_seen_at: 1.day.ago) }

  def user_error_message(*keys)
    I18n.t(:"activerecord.errors.models.user.attributes.#{keys.join('.')}")
  end

  it { is_expected.to have_many(:pending_posts).class_name('ReviewableQueuedPost').with_foreign_key(:created_by_id) }

  context 'validations' do
    describe '#username' do
      it { is_expected.to validate_presence_of :username }

      describe 'when username already exists' do
        it 'should not be valid' do
          new_user = Fabricate.build(:user, username: user.username.upcase)

          expect(new_user).to_not be_valid

          expect(new_user.errors.full_messages.first)
            .to include(I18n.t(:'user.username.unique'))
        end
      end

      describe 'when group with a same name already exists' do
        it 'should not be valid' do
          new_user = Fabricate.build(:user, username: group.name.upcase)

          expect(new_user).to_not be_valid

          expect(new_user.errors.full_messages.first)
            .to include(I18n.t(:'user.username.unique'))
        end
      end

      it 'is not valid if username changes to be same as password' do
        user.username = 'myawesomepassword'
        expect(user).to_not be_valid
        expect(user.errors.full_messages.first)
          .to include(user_error_message(:username, :same_as_password))
      end

      it 'is not valid if username lowercase changes to be same as password' do
        user.username = 'MyAwesomePassword'
        expect(user).to_not be_valid
        expect(user.errors.full_messages.first)
          .to include(user_error_message(:username, :same_as_password))
      end
    end

    describe 'name' do
      it 'is not valid if it changes to be the same as the password' do
        user.name = 'myawesomepassword'
        expect(user).to_not be_valid
        expect(user.errors.full_messages.first)
          .to include(user_error_message(:name, :same_as_password))
      end

      it 'is not valid if name lowercase changes to be the same as the password' do
        user.name = 'MyAwesomePassword'
        expect(user).to_not be_valid
        expect(user.errors.full_messages.first)
          .to include(user_error_message(:name, :same_as_password))
      end

      it "doesn't raise an error if the name is longer than the max password length" do
        user.name = 'x' * (User.max_password_length + 1)
        expect(user).to be_valid
      end
    end

    describe 'emails' do
      it { is_expected.to validate_presence_of :primary_email }

      let(:user) { Fabricate.build(:user) }

      describe 'when record has a valid email' do
        it "should be valid" do
          user.email = 'test@gmail.com'

          expect(user).to be_valid
        end
      end

      describe 'when record has an invalid email' do
        it 'should not be valid' do
          user.email = 'test@gmailcom'

          expect(user).to_not be_valid
          expect(user.errors.messages.keys).to contain_exactly(:primary_email)
        end
      end

      describe 'when record has an email that as already been taken' do
        it 'should not be valid' do
          user2 = Fabricate(:user)
          user.email = user2.email.upcase

          expect(user).to_not be_valid

          expect(user.errors.messages[:primary_email]).to include(I18n.t(
            'activerecord.errors.messages.taken'
          ))
        end
      end

      describe 'when user is staged' do
        it 'should still validate presence of primary_email' do
          user.staged = true
          user.email = nil

          expect(user).to_not be_valid
          expect(user.errors.messages).to include(:primary_email)
        end
      end

      describe 'when primary_email is being reassigned to another user' do
        it "should not be valid" do
          user2 = Fabricate.build(:user, email: nil)
          user.save!
          user2.primary_email = user.primary_email

          expect(user2).to_not be_valid
          expect(user2.errors.messages).to include(:primary_email)
          expect(user2.primary_email.errors.messages).to include(:user_id)
        end
      end
    end
  end

  describe '#count_by_signup_date' do
    before(:each) do
      User.destroy_all
      freeze_time DateTime.parse('2017-02-01 12:00')
      Fabricate(:user)
      Fabricate(:user, created_at: 1.day.ago)
      Fabricate(:user, created_at: 1.day.ago)
      Fabricate(:user, created_at: 2.days.ago)
      Fabricate(:user, created_at: 4.days.ago)
    end
    let(:signups_by_day) { { 1.day.ago.to_date => 2, 2.days.ago.to_date => 1, Time.now.utc.to_date => 1 } }

    it 'collect closed interval signups' do
      expect(User.count_by_signup_date(2.days.ago, Time.now)).to include(signups_by_day)
      expect(User.count_by_signup_date(2.days.ago, Time.now)).not_to include(4.days.ago.to_date => 1)
    end
  end

  context '.enqueue_welcome_message' do
    fab!(:user) { Fabricate(:user) }

    it 'enqueues the system message' do
      SiteSetting.send_welcome_message = true

      expect_enqueued_with(job: :send_system_message, args: { user_id: user.id, message_type: 'welcome_user' }) do
        user.enqueue_welcome_message('welcome_user')
      end
    end

    it "doesn't enqueue the system message when the site settings disable it" do
      SiteSetting.send_welcome_message = false

      expect_not_enqueued_with(job: :send_system_message, args: { user_id: user.id, message_type: 'welcome_user' }) do
        user.enqueue_welcome_message('welcome_user')
      end
    end
  end

  context 'enqueue_staff_welcome_message' do
    fab!(:first_admin) { Fabricate(:admin) }
    fab!(:user) { Fabricate(:user) }

    it 'enqueues message for admin' do
      expect {
        user.grant_admin!
      }.to change { Jobs::SendSystemMessage.jobs.count }.by 1
    end

    it 'enqueues message for moderator' do
      expect {
        user.grant_moderation!
      }.to change { Jobs::SendSystemMessage.jobs.count }.by 1
    end

    it 'skips the message if already an admin' do
      user.update(admin: true)
      expect {
        user.grant_admin!
      }.to change { Jobs::SendSystemMessage.jobs.count }.by 0
    end
  end

  context '.set_default_tags_preferences' do
    let(:tag) { Fabricate(:tag) }

    it "should set default tag preferences when new user created" do
      SiteSetting.default_tags_watching = tag.name
      user = Fabricate(:user)
      expect(TagUser.exists?(tag_id: tag.id, user_id: user.id, notification_level: TagUser.notification_levels[:watching])).to be_truthy
    end
  end

  describe 'reviewable' do
    let(:user) { Fabricate(:user, active: false) }
    fab!(:admin) { Fabricate(:admin) }

    before do
      Jobs.run_immediately!
    end

    it "creates a reviewable for the user if must_approve_users is true and activate is called" do
      SiteSetting.must_approve_users = true
      user

      # Inactive users don't have reviewables
      reviewable = ReviewableUser.find_by(target: user)
      expect(reviewable).to be_blank

      user.activate
      reviewable = ReviewableUser.find_by(target: user)
      expect(reviewable).to be_present
      expect(reviewable.score > 0).to eq(true)
      expect(reviewable.reviewable_scores).to be_present
    end

    it "creates a reviewable for the user if must_approve_users is true and their token is confirmed" do
      SiteSetting.must_approve_users = true
      user

      # Inactive users don't have reviewables
      reviewable = ReviewableUser.find_by(target: user)
      expect(reviewable).to be_blank

      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      expect(user.reload.active).to eq(true)
      reviewable = ReviewableUser.find_by(target: user)
      expect(reviewable).to be_present
    end

    it "doesn't create a reviewable if must_approve_users is false" do
      user
      expect(ReviewableUser.find_by(target: user)).to be_blank
    end

    it "will reject a reviewable if the user is deactivated" do
      SiteSetting.must_approve_users = true
      user

      user.activate
      reviewable = ReviewableUser.find_by(target: user)
      expect(reviewable.pending?).to eq(true)

      user.deactivate(admin)
      expect(reviewable.reload.rejected?).to eq(true)
    end
  end

  describe 'bookmark' do
    before_all do
      @post = Fabricate(:post)
    end

    it "creates a bookmark with the true parameter" do
      expect {
        PostActionCreator.create(@post.user, @post, :bookmark)
      }.to change(PostAction, :count).by(1)
    end

    describe 'when removing a bookmark' do
      before do
        PostActionCreator.create(@post.user, @post, :bookmark)
      end

      it 'reduces the bookmark count of the post' do
        active = PostAction.where(deleted_at: nil)
        expect {
          PostActionDestroyer.destroy(@post.user, @post, :bookmark)
        }.to change(active, :count).by(-1)
      end
    end
  end

  describe 'delete posts in batches' do
    fab!(:post1) { Fabricate(:post) }
    fab!(:user) { post1.user }
    fab!(:post2) { Fabricate(:post, topic: post1.topic, user: user) }
    fab!(:post3) { Fabricate(:post, user: user) }
    fab!(:posts) { [post1, post2, post3] }
    fab!(:post_ids) { [post1.id, post2.id, post3.id] }
    fab!(:guardian) { Guardian.new(Fabricate(:admin)) }
    fab!(:reviewable_queued_post) { Fabricate(:reviewable_queued_post, created_by: user) }

    it 'deletes only one batch of posts' do
      post2
      deleted_posts = user.delete_posts_in_batches(guardian, 1)
      expect(Post.where(id: post_ids).count).to eq(2)
      expect(deleted_posts.length).to eq(1)
      expect(deleted_posts[0]).to eq(post2)
    end

    it 'correctly deletes posts and topics' do
      posts
      user.delete_posts_in_batches(guardian, 20)

      expect(Post.where(id: post_ids)).to be_empty
      expect(Reviewable.where(created_by: user).count).to eq(0)

      posts.each do |p|
        if p.is_first_post?
          expect(Topic.find_by(id: p.topic_id)).to be_nil
        end
      end
    end

    it 'does not allow non moderators to delete all posts' do
      invalid_guardian = Guardian.new(Fabricate(:user))

      expect do
        user.delete_posts_in_batches(invalid_guardian)
      end.to raise_error Discourse::InvalidAccess

      posts.each do |p|
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
    end

    it 'triggers an extensibility event' do
      event = DiscourseEvent.track_events { subject.save! }.first

      expect(event[:event_name]).to eq(:user_created)
      expect(event[:params].first).to eq(subject)
    end

    context 'after_save' do
      before { subject.save! }

      it "has correct settings" do
        expect(subject.email_tokens).to be_present
        expect(subject.user_stat).to be_present
        expect(subject.user_profile).to be_present
        expect(subject.user_option.email_messages_level).to eq(UserOption.email_level_types[:always])
        expect(subject.user_option.email_level).to eq(UserOption.email_level_types[:only_when_away])
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
        expect { user.has_trust_level?(:wat) }.to raise_error(InvalidTrustLevel)
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
    before_all do
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
      expect(user.associated_accounts).to eq([])

      UserAssociatedAccount.create(user_id: user.id, provider_name: "twitter", provider_uid: "1", info: { nickname: "sam" })
      UserAssociatedAccount.create(user_id: user.id, provider_name: "facebook", provider_uid: "1234", info: { email: "test@example.com" })
      UserAssociatedAccount.create(user_id: user.id, provider_name: "discord", provider_uid: "examplel123123", info: { nickname: "sam" })
      UserAssociatedAccount.create(user_id: user.id, provider_name: "google_oauth2", provider_uid: "1", info: { email: "sam@sam.com" })
      UserAssociatedAccount.create(user_id: user.id, provider_name: "github", provider_uid: "1", info: { nickname: "sam" })

      user.reload
      expect(user.associated_accounts.map { |a| a[:name] }).to contain_exactly('twitter', 'facebook', 'google_oauth2', 'github', 'discord')

    end
  end

  describe '.is_singular_admin?' do
    it 'returns true if user is singular admin' do
      admin = Fabricate(:admin)
      expect(admin.is_singular_admin?).to eq(true)
    end

    it 'returns false if user is not the only admin' do
      admin = Fabricate(:admin)
      Fabricate(:admin)

      expect(admin.is_singular_admin?).to eq(false)
    end
  end

  describe 'name heuristics' do
    it 'is able to guess a decent name from an email' do
      expect(User.suggest_name('sam.saffron@gmail.com')).to eq('Sam Saffron')
    end

    it 'is able to guess a decent name from username' do
      expect(User.suggest_name('@sam.saffron')).to eq('Sam Saffron')
    end

    it 'is able to guess a decent name from name' do
      expect(User.suggest_name('sam saffron')).to eq('Sam Saffron')
    end
  end

  describe 'username format' do
    fab!(:user) { Fabricate(:user) }

    def assert_bad(username)
      user.username = username
      expect(user.valid?).to eq(false)
    end

    def assert_good(username)
      user.username = username
      expect(user.valid?).to eq(true)
    end

    it "should be SiteSetting.min_username_length chars or longer" do
      SiteSetting.min_username_length = 5
      assert_bad("abcd")
      assert_good("abcde")
    end

    context 'when Unicode usernames are disabled' do
      before { SiteSetting.unicode_usernames = false }

      %w{
        first.last
        first
        first-last
        _name
        first_last
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

    context 'when Unicode usernames are enabled' do
      before { SiteSetting.unicode_usernames = true }

      %w{
        Джофрэй
        Джо.фрэй
        Джофр-эй
        Д.жофрэй
        乔夫雷
        乔夫_雷
        _乔夫雷
      }.each do |username|
        it "allows #{username}" do
          assert_good(username)
        end
      end

      %w{
        .Джофрэй
        Джофрэй.
        Джо\ фрэй
        Джоф__рэй
        乔夫雷.js
        乔夫雷.
        乔夫%雷
      }.each do |username|
        it "disallows #{username}" do
          assert_bad(username)
        end
      end
    end
  end

  describe 'username uniqueness' do
    before_all do
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

  describe '.username_available?' do
    it "returns true for a username that is available" do
      expect(User.username_available?('BruceWayne')).to eq(true)
    end

    it 'returns false when a username is taken' do
      expect(User.username_available?(Fabricate(:user).username)).to eq(false)
    end

    it 'returns false when a username is reserved' do
      SiteSetting.reserved_usernames = 'test|donkey'
      expect(User.username_available?('tESt')).to eq(false)
    end

    it 'returns true when reserved username is explicitly allowed' do
      SiteSetting.reserved_usernames = 'test|donkey'

      expect(User.username_available?(
        'tESt',
        nil,
        allow_reserved_username: true)
      ).to eq(true)
    end

    it "returns true when username is associated to a staged user of the same email" do
      staged = Fabricate(:user, staged: true, email: "foo@bar.com")
      expect(User.username_available?(staged.username, staged.primary_email.email)).to eq(true)

      user = Fabricate(:user, email: "bar@foo.com")
      expect(User.username_available?(user.username, user.primary_email.email)).to eq(false)
    end

    it 'returns false when a username equals an existing group name' do
      Fabricate(:group, name: 'foo')
      expect(User.username_available?('Foo')).to eq(false)
    end

    context "with Unicode usernames enabled" do
      before { SiteSetting.unicode_usernames = true }

      it 'returns false when the username is taken, but the Unicode normalization form is different' do
        Fabricate(:user, username: "L\u00F6we") # NFC
        requested_username = "Lo\u0308we" # NFD
        expect(User.username_available?(requested_username)).to eq(false)
      end

      it 'returns false when the username is taken and the case differs' do
        Fabricate(:user, username: 'LÖWE')
        expect(User.username_available?('löwe')).to eq(false)
      end
    end
  end

  describe '.reserved_username?' do
    it 'returns true when a username is reserved' do
      SiteSetting.reserved_usernames = 'test|donkey'

      expect(User.reserved_username?('donkey')).to eq(true)
      expect(User.reserved_username?('DonKey')).to eq(true)
      expect(User.reserved_username?('test')).to eq(true)
    end

    it 'should not allow usernames matched against an expression' do
      SiteSetting.reserved_usernames = "test)|*admin*|foo*|*bar|abc.def|löwe|ka\u0308fer"

      expect(User.reserved_username?('test')).to eq(false)
      expect(User.reserved_username?('abc9def')).to eq(false)

      expect(User.reserved_username?('admin')).to eq(true)
      expect(User.reserved_username?('foo')).to eq(true)
      expect(User.reserved_username?('bar')).to eq(true)

      expect(User.reserved_username?('admi')).to eq(false)
      expect(User.reserved_username?('bar.foo')).to eq(false)
      expect(User.reserved_username?('foo.bar')).to eq(true)
      expect(User.reserved_username?('baz.bar')).to eq(true)

      expect(User.reserved_username?('LÖwe')).to eq(true)
      expect(User.reserved_username?("Lo\u0308we")).to eq(true) # NFD
      expect(User.reserved_username?('löwe')).to eq(true) # NFC
      expect(User.reserved_username?('käfer')).to eq(true) # NFC
    end
  end

  describe 'email_validator' do
    it 'should allow good emails' do
      user = Fabricate.build(:user, email: 'good@gmail.com')
      expect(user).to be_valid
    end

    it 'should reject some emails based on the blocked_email_domains site setting' do
      SiteSetting.blocked_email_domains = 'mailinator.com'
      expect(Fabricate.build(:user, email: 'notgood@mailinator.com')).not_to be_valid
      expect(Fabricate.build(:user, email: 'mailinator@gmail.com')).to be_valid
    end

    it 'should reject some emails based on the blocked_email_domains site setting' do
      SiteSetting.blocked_email_domains = 'mailinator.com|trashmail.net'
      expect(Fabricate.build(:user, email: 'notgood@mailinator.com')).not_to be_valid
      expect(Fabricate.build(:user, email: 'notgood@trashmail.net')).not_to be_valid
      expect(Fabricate.build(:user, email: 'mailinator.com@gmail.com')).to be_valid
    end

    it 'should not reject partial matches' do
      SiteSetting.blocked_email_domains = 'mail.com'
      expect(Fabricate.build(:user, email: 'mailinator@gmail.com')).to be_valid
    end

    it 'should reject some emails based on the blocked_email_domains site setting ignoring case' do
      SiteSetting.blocked_email_domains = 'trashmail.net'
      expect(Fabricate.build(:user, email: 'notgood@TRASHMAIL.NET')).not_to be_valid
    end

    it 'should reject emails based on the blocked_email_domains site setting matching subdomain' do
      SiteSetting.blocked_email_domains = 'domain.com'
      expect(Fabricate.build(:user, email: 'notgood@sub.domain.com')).not_to be_valid
    end

    it 'skips the blocklist if skip_email_validation is set' do
      SiteSetting.blocked_email_domains = 'domain.com'
      user = Fabricate.build(:user, email: 'notgood@sub.domain.com')
      user.skip_email_validation = true
      expect(user).to be_valid
    end

    it 'blocklist should not reject developer emails' do
      Rails.configuration.stubs(:developer_emails).returns('developer@discourse.org')
      SiteSetting.blocked_email_domains = 'discourse.org'
      expect(Fabricate.build(:user, email: 'developer@discourse.org')).to be_valid
    end

    it 'should not interpret a period as a wildcard' do
      SiteSetting.blocked_email_domains = 'trashmail.net'
      expect(Fabricate.build(:user, email: 'good@trashmailinet.com')).to be_valid
    end

    it 'should not be used to validate existing records' do
      u = Fabricate(:user, email: 'in_before_blocklisted@fakemail.com')
      SiteSetting.blocked_email_domains = 'fakemail.com'
      expect(u).to be_valid
    end

    it 'should be used when email is being changed' do
      SiteSetting.blocked_email_domains = 'mailinator.com'
      u = Fabricate(:user, email: 'good@gmail.com')
      u.email = 'nope@mailinator.com'
      expect(u).not_to be_valid
    end

    it 'allowlist should reject some emails based on the allowed_email_domains site setting' do
      SiteSetting.allowed_email_domains = 'vaynermedia.com'
      user = Fabricate.build(:user, email: 'notgood@mailinator.com')
      expect(user).not_to be_valid
      expect(user.errors.messages[:primary_email]).to include(I18n.t('user.email.not_allowed'))
      expect(Fabricate.build(:user, email: 'sbauch@vaynermedia.com')).to be_valid
    end

    it 'should reject some emails based on the allowed_email_domains site setting when allowlisting multiple domains' do
      SiteSetting.allowed_email_domains = 'vaynermedia.com|gmail.com'
      expect(Fabricate.build(:user, email: 'notgood@mailinator.com')).not_to be_valid
      expect(Fabricate.build(:user, email: 'notgood@trashmail.net')).not_to be_valid
      expect(Fabricate.build(:user, email: 'mailinator.com@gmail.com')).to be_valid
      expect(Fabricate.build(:user, email: 'mailinator.com@vaynermedia.com')).to be_valid
    end

    it 'should accept some emails based on the allowed_email_domains site setting ignoring case' do
      SiteSetting.allowed_email_domains = 'vaynermedia.com'
      expect(Fabricate.build(:user, email: 'good@VAYNERMEDIA.COM')).to be_valid
    end

    it 'allowlist should accept developer emails' do
      Rails.configuration.stubs(:developer_emails).returns('developer@discourse.org')
      SiteSetting.allowed_email_domains = 'awesome.org'
      expect(Fabricate.build(:user, email: 'developer@discourse.org')).to be_valid
    end

    it 'email allowlist should not be used to validate existing records' do
      u = Fabricate(:user, email: 'in_before_allowlisted@fakemail.com')
      SiteSetting.blocked_email_domains = 'vaynermedia.com'
      expect(u).to be_valid
    end

    it 'email allowlist should be used when email is being changed' do
      SiteSetting.allowed_email_domains = 'vaynermedia.com'
      u = Fabricate(:user, email: 'good@vaynermedia.com')
      u.email = 'nope@mailinator.com'
      expect(u).not_to be_valid
    end

    it "doesn't validate email address for staged users" do
      SiteSetting.allowed_email_domains = "foo.com"
      SiteSetting.blocked_email_domains = "bar.com"

      user = Fabricate.build(:user, staged: true, email: "foo@bar.com")

      expect(user.save).to eq(true)
    end
  end

  describe 'passwords' do

    it "should not have an active account with a good password" do
      @user = Fabricate.build(:user, active: false)
      @user.password = "ilovepasta"
      @user.save!

      expect(@user.active).to eq(false)
      expect(@user.confirm_password?("ilovepasta")).to eq(true)

      email_token = Fabricate(:email_token, user: @user, email: 'pasta@delicious.com')

      UserAuthToken.generate!(user_id: @user.id)

      @user.password = "passwordT0"
      @user.save!

      # must expire old token on password change
      expect(@user.user_auth_tokens.count).to eq(0)

      email_token.reload
      expect(email_token.expired).to eq(true)
    end
  end

  describe "previous_visit_at" do
    fab!(:user) { Fabricate(:user) }
    let!(:first_visit_date) { Time.zone.now }
    let!(:second_visit_date) { 2.hours.from_now }
    let!(:third_visit_date) { 5.hours.from_now }

    before do
      SiteSetting.active_user_rate_limit_secs = 0
      SiteSetting.previous_visit_timeout_hours = 1
    end

    after do
      reset_last_seen_cache!(user)
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
      expect(user.previous_visit_at).to eq_time(first_visit_date)

      # third visit
      user.update_last_seen!(third_visit_date)
      user.reload
      expect(user.previous_visit_at).to eq_time(second_visit_date)
    end

  end

  describe "update_last_seen!" do
    fab!(:user) { Fabricate(:user) }
    let!(:first_visit_date) { Time.zone.now }
    let!(:second_visit_date) { 2.hours.from_now }

    after do
      reset_last_seen_cache!(user)
    end

    it "should update the last seen value" do
      expect(user.last_seen_at).to eq nil
      user.update_last_seen!(first_visit_date)
      expect(user.reload.last_seen_at).to eq_time(first_visit_date)
    end

    it "should update the first seen value if it doesn't exist" do
      user.update_last_seen!(first_visit_date)
      expect(user.reload.first_seen_at).to eq_time(first_visit_date)
    end

    it "should not update the first seen value if it doesn't exist" do
      user.update_last_seen!(first_visit_date)
      user.update_last_seen!(second_visit_date)
      expect(user.reload.first_seen_at).to eq_time(first_visit_date)
    end
  end

  describe "update_timezone_if_missing" do
    let(:timezone) { nil }

    it "does nothing if timezone is nil" do
      user.update_timezone_if_missing(timezone)
      expect(user.reload.user_option.timezone).to eq(nil)
    end

    context "if timezone is provided" do
      context "if the timezone is valid" do
        let(:timezone) { "Australia/Melbourne" }
        context "if no timezone exists on user option" do
          it "sets the timezone for the user" do
            user.update_timezone_if_missing(timezone)
            expect(user.reload.user_option.timezone).to eq(timezone)
          end
        end
      end

      context "if the timezone is not valid" do
        let(:timezone) { "Jupiter" }
        context "if no timezone exists on user option" do
          it "does not set the timezone for the user" do
            user.update_timezone_if_missing(timezone)
            expect(user.reload.user_option.timezone).to eq(nil)
          end
        end
      end

      context "if a timezone already exists on user option" do
        before do
          user.user_option.update_attribute(:timezone, "America/Denver")
        end

        it "does not update the timezone" do
          user.update_timezone_if_missing(timezone)
          expect(user.reload.user_option.timezone).to eq("America/Denver")
        end
      end
    end
  end

  describe "last_seen_at" do
    fab!(:user) { Fabricate(:user) }

    it "should have a blank last seen on creation" do
      expect(user.last_seen_at).to eq(nil)
    end

    it "should have 0 for days_visited" do
      expect(user.user_stat.days_visited).to eq(0)
    end

    describe 'with no previous values' do
      after do
        reset_last_seen_cache!(user)
        unfreeze_time
        reset_last_seen_cache!(user)
      end

      it "updates last_seen_at" do
        date = freeze_time
        user.update_last_seen!

        expect(user.last_seen_at).to eq_time(date)
      end

      it "should have 0 for days_visited" do
        user.update_last_seen!
        user.reload

        expect(user.user_stat.days_visited).to eq(1)
      end

      it "should log a user_visit with the date" do
        date = freeze_time
        user.update_last_seen!

        expect(user.user_visits.first.visited_at).to eq_time(date.to_date)
      end

      context "called twice" do
        it "doesn't increase days_visited twice" do
          freeze_time
          user.update_last_seen!
          user.update_last_seen!
          user.reload

          expect(user.user_stat.days_visited).to eq(1)
        end
      end

      describe "after 3 days" do
        it "should log a second visited_at record when we log an update later" do
          user.update_last_seen!
          future_date = freeze_time(3.days.from_now)
          user.update_last_seen!

          expect(user.user_visits.count).to eq(2)
        end
      end
    end
  end

  describe 'email_confirmed?' do
    fab!(:user) { Fabricate(:user) }

    context 'when email has not been confirmed yet' do
      it 'should return false' do
        expect(user.email_confirmed?).to eq(false)
      end
    end

    context 'when email has been confirmed' do
      it 'should return true' do
        token = Fabricate(:email_token, user: user)
        EmailToken.confirm(token.token)
        expect(user.email_confirmed?).to eq(true)
      end
    end

    context 'when user has no email tokens for some reason' do
      it 'should return false' do
        user.email_tokens.each { |t| t.destroy }
        user.reload
        expect(user.email_confirmed?).to eq(true)
      end
    end
  end

  describe "flag_linked_posts_as_spam" do
    fab!(:user) { Fabricate(:user) }
    fab!(:admin) { Fabricate(:admin) }
    fab!(:post) { PostCreator.new(user, title: "this topic contains spam", raw: "this post has a link: http://discourse.org").create }
    fab!(:another_post) { PostCreator.new(user, title: "this topic also contains spam", raw: "this post has a link: http://discourse.org/asdfa").create }
    fab!(:post_without_link) { PostCreator.new(user, title: "this topic shouldn't be spam", raw: "this post has no links in it.").create }

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

    it "does not flags post as spam if the previous flag for that post was disagreed" do
      results = user.flag_linked_posts_as_spam

      expect(post.reload.spam_count).to eq(1)

      results.each { |result| result.reviewable.perform(admin, :disagree) }

      user.flag_linked_posts_as_spam

      expect(post.reload.spam_count).to eq(0)
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

    it 'finds users with Unicode username' do
      SiteSetting.unicode_usernames = true
      user = Fabricate(:user, username: 'löwe')

      expect(User.find_by_username('LÖWE')).to eq(user) # NFC
      expect(User.find_by_username("LO\u0308WE")).to eq(user) # NFD
      expect(User.find_by_username("lo\u0308we")).to eq(user) # NFD
    end
  end

  describe "#new_user_posting_on_first_day?" do

    def test_user?(opts = {})
      Fabricate.build(:user, { created_at: Time.zone.now }.merge(opts)).new_user_posting_on_first_day?
    end

    it "handles when user has never posted" do
      expect(test_user?).to eq(true)
      expect(test_user?(moderator: true)).to eq(false)
      expect(test_user?(trust_level: TrustLevel[2])).to eq(false)
      expect(test_user?(created_at: 2.days.ago)).to eq(true)
    end

    it "is true for a user who posted less than 24 hours ago but was created over 1 day ago" do
      u = Fabricate(:user, created_at: 28.hours.ago)
      u.user_stat.first_post_created_at = 1.hour.ago
      expect(u.new_user_posting_on_first_day?).to eq(true)
    end

    it "is false if first post was more than 24 hours ago" do
      u = Fabricate(:user, created_at: 28.hours.ago)
      u.user_stat.first_post_created_at = 25.hours.ago
      expect(u.new_user_posting_on_first_day?).to eq(false)
    end

    it "considers trust level 0 users as new users unconditionally" do
      u = Fabricate(:user, created_at: 28.hours.ago, trust_level: TrustLevel[0])
      u.user_stat.first_post_created_at = 25.hours.ago
      expect(u.new_user_posting_on_first_day?).to eq(true)
    end
  end

  describe "posted too much in topic" do
    let!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }
    let!(:topic) { Fabricate(:post).topic }

    before do
      # To make testing easier, say 1 reply is too much
      SiteSetting.newuser_max_replies_per_topic = 1
      UserActionManager.enable
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
          Jobs.run_immediately!
          PostCreator.new(Fabricate(:user),
                          raw: 'whatever this is a raw post',
                          topic_id: topic.id,
                          reply_to_post_number: post.post_number).create
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

    fab!(:user) { Fabricate(:user, email: "bob@example.com") }

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

  describe "#custom_gravatar" do
    before do
      SiteSetting.gravatar_base_url = "seccdn.libravatar.org"
    end

    it "returns a gravatar url as set in the settings" do
      expect(User.gravatar_template("em@il.com")).to eq("//seccdn.libravatar.org/avatar/6dc2fde946483a1d8a84b89345a1b638.png?s={size}&r=pg&d=identicon")
    end
  end

  describe "#letter_avatar_color" do
    before do
      SiteSetting.restrict_letter_avatar_colors = "2F70AC|ED207B|AAAAAA|77FF33"
    end

    it "returns custom color if restrict_letter_avatar_colors site setting is set" do
      expect(User.letter_avatar_color("username_one")).to eq("2F70AC")
      expect(User.letter_avatar_color("username_two")).to eq("ED207B")
      expect(User.letter_avatar_color("username_three")).to eq("AAAAAA")
      expect(User.letter_avatar_color("username_four")).to eq("77FF33")
    end
  end

  describe ".small_avatar_url" do

    let(:user) { build(:user, username: 'Sam') }

    it "returns a 45-pixel-wide avatar" do
      SiteSetting.external_system_avatars_enabled = false
      expect(user.small_avatar_url).to eq("//test.localhost/letter_avatar/sam/45/#{LetterAvatar.version}.png")

      SiteSetting.external_system_avatars_enabled = true
      expect(user.small_avatar_url).to eq("//test.localhost/letter_avatar_proxy/v4/letter/s/5f9b8f/45.png")
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

  describe '#avatar_template' do
    it 'uses the small logo if the user is the system user' do
      logo_small_url = Discourse.store.cdn_url(SiteSetting.logo_small.url)

      expect(Discourse.system_user.avatar_template).to eq(logo_small_url)
    end

    it 'uses the system user avatar if the logo is nil' do
      SiteSetting.logo_small = nil
      system_user = Discourse.system_user
      expected = User.avatar_template(system_user.username, system_user.uploaded_avatar_id)

      expect(Discourse.system_user.avatar_template).to eq(expected)
    end

    it 'uses the regular avatar for other users' do
      user = Fabricate(:user)
      expected = User.avatar_template(user.username, user.uploaded_avatar_id)

      expect(user.avatar_template).to eq(expected)
    end
  end

  describe "update_posts_read!" do
    context "with a UserVisit record" do
      fab!(:user) { Fabricate(:user) }
      let!(:now) { Time.zone.now }
      before { user.update_last_seen!(now) }
      after do
        reset_last_seen_cache!(user)
      end

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
    fab!(:user) { Fabricate(:user) }

    it "has no primary_group_id by default" do
      expect(user.primary_group_id).to eq(nil)
    end

    context "when the user has a group" do

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

      expect(user.custom_fields).to eq("jack" => "jill")
    end
  end

  describe "refresh_avatar" do
    it "enqueues the update_gravatar job when automatically downloading gravatars" do
      SiteSetting.automatically_download_gravatars = true

      user = Fabricate(:user)

      expect_enqueued_with(job: :update_gravatar, args: { user_id: user.id }) do
        user.refresh_avatar
      end
    end
  end

  describe "#purge_unactivated" do
    fab!(:user) { Fabricate(:user) }
    fab!(:unactivated) { Fabricate(:user, active: false) }
    fab!(:unactivated_old) { Fabricate(:user, active: false, created_at: 1.month.ago) }
    fab!(:unactivated_old_with_system_pm) { Fabricate(:user, active: false, created_at: 2.months.ago) }
    fab!(:unactivated_old_with_human_pm) { Fabricate(:user, active: false, created_at: 2.months.ago) }
    fab!(:unactivated_old_with_post) { Fabricate(:user, active: false, created_at: 1.month.ago) }

    before do
      PostCreator.new(Discourse.system_user,
                      title: "Welcome to our Discourse",
                      raw: "This is a welcome message",
                      archetype: Archetype.private_message,
                      target_usernames: [unactivated_old_with_system_pm.username],
      ).create

      PostCreator.new(user,
                      title: "Welcome to our Discourse",
                      raw: "This is a welcome message",
                      archetype: Archetype.private_message,
                      target_usernames: [unactivated_old_with_human_pm.username],
      ).create

      PostCreator.new(unactivated_old_with_post,
                      title: "Test topic from a user",
                      raw: "This is a sample message"
      ).create
    end

    it 'should only remove old, unactivated users' do
      User.purge_unactivated
      expect(User.real.all).to match_array([user, unactivated, unactivated_old_with_human_pm, unactivated_old_with_post])
    end

    it "does nothing if purge_unactivated_users_grace_period_days is 0" do
      SiteSetting.purge_unactivated_users_grace_period_days = 0
      User.purge_unactivated
      expect(User.real.all).to match_array([
        user, unactivated, unactivated_old, unactivated_old_with_system_pm, unactivated_old_with_human_pm, unactivated_old_with_post
      ])
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
      expect { hash(too_long, 'gravy') }.to raise_error(StandardError)
    end

  end

  describe "automatic group membership" do

    fab!(:group) {
      Fabricate(:group,
                automatic_membership_email_domains: "bar.com|wat.com",
                grant_trust_level: 1,
                title: "bars and wats",
                primary_group: true
      )
    }

    it "doesn't automatically add staged users" do
      staged_user = Fabricate(:user, active: true, staged: true, email: "wat@wat.com")
      EmailToken.confirm(Fabricate(:email_token, user: staged_user).token)
      group.reload
      expect(group.users.include?(staged_user)).to eq(false)
    end

    it "is automatically added to a group when the email matches" do
      user = Fabricate(:user, active: true, email: "foo@bar.com")
      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      group.reload
      expect(group.users.include?(user)).to eq(true)

      group_history = GroupHistory.last

      expect(group_history.action).to eq(GroupHistory.actions[:add_user_to_group])
      expect(group_history.acting_user).to eq(Discourse.system_user)
      expect(group_history.target_user).to eq(user)
    end

    it "is automatically added to a group when the email matches the SSO record" do
      user = Fabricate(:user, active: true, email: "sso@bar.com")
      user.create_single_sign_on_record(external_id: 123, external_email: "sso@bar.com", last_payload: "")
      user.set_automatic_groups
      group.reload
      expect(group.users.include?(user)).to eq(true)
    end

    it "get attributes from the group" do
      user = Fabricate.build(:user,
                             active: true,
                             trust_level: 0,
                             email: "foo@bar.com",
                             password: "strongpassword4Uguys"
      )

      user.password_required!
      user.save!
      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      user.reload

      expect(user.title).to eq("bars and wats")
      expect(user.trust_level).to eq(1)
      expect(user.manual_locked_trust_level).to be_nil
      expect(user.group_granted_trust_level).to eq(1)
    end
  end

  describe 'staff info' do
    fab!(:user) { Fabricate(:user) }
    fab!(:moderator) { Fabricate(:moderator) }

    describe "#number_of_flags_given" do
      it "doesn't count disagreed flags" do
        post_agreed = Fabricate(:post)
        PostActionCreator.inappropriate(user, post_agreed).reviewable.perform(moderator, :agree_and_keep)

        post_deferred = Fabricate(:post)
        PostActionCreator.inappropriate(user, post_deferred).reviewable.perform(moderator, :ignore)

        post_disagreed = Fabricate(:post)
        PostActionCreator.inappropriate(user, post_disagreed).reviewable.perform(moderator, :disagree)

        expect(user.number_of_flags_given).to eq(2)
      end
    end

    describe "number_of_deleted_posts" do
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

    describe '#number_of_rejected_posts' do
      it 'counts rejected posts' do
        Fabricate(:reviewable_queued_post, created_by: user, status: Reviewable.statuses[:rejected])

        expect(user.number_of_rejected_posts).to eq(1)
      end

      it 'ignore non-rejected posts' do
        Fabricate(:reviewable_queued_post, created_by: user, status: Reviewable.statuses[:approved])

        expect(user.number_of_rejected_posts).to eq(0)
      end
    end

    describe '#number_of_flagged_posts' do
      it 'counts flagged posts from the user' do
        Fabricate(:reviewable_flagged_post, target_created_by: user)

        expect(user.number_of_flagged_posts).to eq(1)
      end

      it 'ignores flagged posts from another user' do
        Fabricate(:reviewable_flagged_post, target_created_by: Fabricate(:user))

        expect(user.number_of_flagged_posts).to eq(0)
      end
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

    fab!(:category0) { Fabricate(:category) }
    fab!(:category1) { Fabricate(:category) }
    fab!(:category2) { Fabricate(:category) }
    fab!(:category3) { Fabricate(:category) }
    fab!(:category4) { Fabricate(:category) }

    before do
      SiteSetting.default_email_digest_frequency = 1440 # daily
      SiteSetting.default_email_level = UserOption.email_level_types[:never]
      SiteSetting.default_email_messages_level = UserOption.email_level_types[:never]
      SiteSetting.disable_mailing_list_mode = false
      SiteSetting.default_email_mailing_list_mode = true

      SiteSetting.default_other_new_topic_duration_minutes = -1 # not viewed
      SiteSetting.default_other_auto_track_topics_after_msecs = 0 # immediately
      SiteSetting.default_other_notification_level_when_replying = 3 # immediately
      SiteSetting.default_other_external_links_in_new_tab = true
      SiteSetting.default_other_enable_quoting = false
      SiteSetting.default_other_dynamic_favicon = true
      SiteSetting.default_other_skip_new_user_tips = true

      SiteSetting.default_topics_automatic_unpin = false

      SiteSetting.default_categories_watching = category0.id.to_s
      SiteSetting.default_categories_tracking = category1.id.to_s
      SiteSetting.default_categories_muted = category2.id.to_s
      SiteSetting.default_categories_watching_first_post = category3.id.to_s
      SiteSetting.default_categories_regular = category4.id.to_s
    end

    it "has overriden preferences" do
      user = Fabricate(:user)
      options = user.user_option
      expect(options.mailing_list_mode).to eq(true)
      expect(options.digest_after_minutes).to eq(1440)
      expect(options.email_level).to eq(UserOption.email_level_types[:never])
      expect(options.email_messages_level).to eq(UserOption.email_level_types[:never])
      expect(options.external_links_in_new_tab).to eq(true)
      expect(options.enable_quoting).to eq(false)
      expect(options.dynamic_favicon).to eq(true)
      expect(options.skip_new_user_tips).to eq(true)
      expect(options.automatically_unpin_topics).to eq(false)
      expect(options.new_topic_duration_minutes).to eq(-1)
      expect(options.auto_track_topics_after_msecs).to eq(0)
      expect(options.notification_level_when_replying).to eq(3)

      expect(CategoryUser.lookup(user, :watching).pluck(:category_id)).to eq([category0.id])
      expect(CategoryUser.lookup(user, :tracking).pluck(:category_id)).to eq([category1.id])
      expect(CategoryUser.lookup(user, :muted).pluck(:category_id)).to eq([category2.id])
      expect(CategoryUser.lookup(user, :watching_first_post).pluck(:category_id)).to eq([category3.id])
      expect(CategoryUser.lookup(user, :regular).pluck(:category_id)).to eq([category4.id])
    end

    it "does not set category preferences for staged users" do
      user = Fabricate(:user, staged: true)
      expect(CategoryUser.lookup(user, :watching).pluck(:category_id)).to eq([])
      expect(CategoryUser.lookup(user, :tracking).pluck(:category_id)).to eq([])
      expect(CategoryUser.lookup(user, :muted).pluck(:category_id)).to eq([])
      expect(CategoryUser.lookup(user, :watching_first_post).pluck(:category_id)).to eq([])
      expect(CategoryUser.lookup(user, :regular).pluck(:category_id)).to eq([])
    end
  end

  context UserOption do

    it "Creates a UserOption row when a user record is created and destroys once done" do
      user = Fabricate(:user)
      expect(user.user_option.email_level).to eq(UserOption.email_level_types[:only_when_away])

      user_id = user.id
      user.destroy!
      expect(UserOption.find_by(user_id: user_id)).to eq(nil)

    end

  end

  describe "#logged_out" do
    fab!(:user) { Fabricate(:user) }

    it 'should publish the right message' do
      message = MessageBus.track_publish('/logout') { user.logged_out }.first

      expect(message.data).to eq(user.id)
    end
  end

  describe '#read_first_notification?' do
    fab!(:user) { Fabricate(:user, trust_level: TrustLevel[0]) }
    fab!(:notification) { Fabricate(:private_message_notification) }

    describe 'when first notification has not been seen' do
      it 'should return the right value' do
        expect(user.read_first_notification?).to eq(false)
      end
    end

    describe 'when first notification has been seen' do
      it 'should return the right value' do
        user.update!(seen_notification_id: notification.id)
        expect(user.reload.read_first_notification?).to eq(true)
      end
    end

    describe 'when user is trust level 1' do
      it 'should return the right value' do
        user.update!(trust_level: TrustLevel[1])

        expect(user.read_first_notification?).to eq(false)
      end
    end

    describe 'when user is trust level 2' do
      it 'should return the right value' do
        user.update!(trust_level: TrustLevel[2])

        expect(user.read_first_notification?).to eq(true)
      end
    end

    describe 'when user is an old user' do
      it 'should return the right value' do
        user.update!(first_seen_at: 1.year.ago)

        expect(user.read_first_notification?).to eq(true)
      end
    end

    describe 'when user skipped new user tips' do
      it 'should return the right value' do
        user.user_option.update!(skip_new_user_tips: true)

        expect(user.read_first_notification?).to eq(true)
      end
    end
  end

  describe "#featured_user_badges" do
    fab!(:user) { Fabricate(:user) }
    let!(:user_badge_tl1) { UserBadge.create(badge_id: Badge::BasicUser, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }
    let!(:user_badge_tl2) { UserBadge.create(badge_id: Badge::Member, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }
    let!(:user_badge_like) { UserBadge.create(badge_id: Badge::FirstLike, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }

    it 'should display badges in the correct order' do
      expect(user.featured_user_badges.map(&:badge_id)).to eq([Badge::Member, Badge::FirstLike, Badge::BasicUser])
    end
  end

  describe ".clear_global_notice_if_needed" do

    fab!(:user) { Fabricate(:user) }
    fab!(:admin) { Fabricate(:admin) }

    before do
      SiteSetting.has_login_hint = true
      SiteSetting.global_notice = "some notice"
    end

    it "doesn't clear the login hint when a regular user is saved" do
      user.save
      expect(SiteSetting.has_login_hint).to eq(true)
      expect(SiteSetting.global_notice).to eq("some notice")
    end

    it "doesn't clear the notice when a system user is saved" do
      Discourse.system_user.save
      expect(SiteSetting.has_login_hint).to eq(true)
      expect(SiteSetting.global_notice).to eq("some notice")
    end

    it "clears the notice when the admin is saved" do
      admin.save
      expect(SiteSetting.has_login_hint).to eq(false)
      expect(SiteSetting.global_notice).to eq("")
    end

  end

  describe '.human_users' do
    it 'should only return users with a positive primary key' do
      Fabricate(:user, id: -1979)
      user = Fabricate(:user)

      expect(User.human_users).to eq([user])
    end
  end

  describe '#publish_notifications_state' do
    it 'should publish the right message sorted by ID desc' do
      notification = Fabricate(:notification, user: user)
      notification2 = Fabricate(:notification, user: user, read: true)

      message = MessageBus.track_publish("/notification/#{user.id}") do
        user.publish_notifications_state
      end.first

      expect(message.data[:recent]).to eq([
        [notification2.id, true], [notification.id, false]
      ])
    end

    it 'floats the unread high priority notifications to the top' do
      notification = Fabricate(:notification, user: user)
      notification2 = Fabricate(:notification, user: user, read: true)
      notification3 = Fabricate(:notification, user: user, notification_type: Notification.types[:private_message])
      notification4 = Fabricate(:notification, user: user, notification_type: Notification.types[:bookmark_reminder])

      message = MessageBus.track_publish("/notification/#{user.id}") do
        user.publish_notifications_state
      end.first

      expect(message.data[:recent]).to eq([
        [notification4.id, false], [notification3.id, false],
        [notification2.id, true], [notification.id, false]
      ])
    end

    it "has the correct counts" do
      notification = Fabricate(:notification, user: user)
      notification2 = Fabricate(:notification, user: user, read: true)
      notification3 = Fabricate(:notification, user: user, notification_type: Notification.types[:private_message])
      notification4 = Fabricate(:notification, user: user, notification_type: Notification.types[:bookmark_reminder])

      message = MessageBus.track_publish("/notification/#{user.id}") do
        user.publish_notifications_state
      end.first

      expect(message.data[:unread_notifications]).to eq(1)
      # NOTE: because of deprecation this will be equal to unread_high_priority_notifications,
      #       to be removed in 2.5
      expect(message.data[:unread_private_messages]).to eq(2)
      expect(message.data[:unread_high_priority_notifications]).to eq(2)
    end

    it "does not publish to the /notification channel for users who have not been seen in > 30 days" do
      notification = Fabricate(:notification, user: user)
      notification2 = Fabricate(:notification, user: user, read: true)
      user.update(last_seen_at: 31.days.ago)

      message = MessageBus.track_publish("/notification/#{user.id}") do
        user.publish_notifications_state
      end.first

      expect(message).to eq(nil)
    end
  end

  describe "silenced?" do

    it "is not silenced by default" do
      expect(Fabricate(:user)).not_to be_silenced
    end

    it "is not silenced with a date in the past" do
      expect(Fabricate(:user, silenced_till: 1.month.ago)).not_to be_silenced
    end

    it "is is silenced with a date in the future" do
      expect(Fabricate(:user, silenced_till: 1.month.from_now)).to be_silenced
    end

    context "finders" do
      let!(:user0) { Fabricate(:user, silenced_till: 1.month.ago) }
      let!(:user1) { Fabricate(:user, silenced_till: 1.month.from_now) }

      it "doesn't return old silenced records" do
        expect(User.silenced).to_not include(user0)
        expect(User.silenced).to include(user1)
        expect(User.not_silenced).to include(user0)
        expect(User.not_silenced).to_not include(user1)
      end
    end
  end

  describe "#unread_notifications" do
    fab!(:user) { Fabricate(:user) }
    before do
      User.max_unread_notifications = 3
    end

    after do
      User.max_unread_notifications = nil
    end

    it "limits to MAX_UNREAD_NOTIFICATIONS" do
      4.times do
        Notification.create!(user_id: user.id, notification_type: 1, read: false, data: '{}')
      end

      expect(user.unread_notifications).to eq(3)
    end

    it "does not include high priority notifications" do
      Notification.create!(user_id: user.id, notification_type: 1, read: false, data: '{}')
      Notification.create!(user_id: user.id, notification_type: Notification.types[:private_message], read: false, data: '{}')
      Notification.create!(user_id: user.id, notification_type: Notification.types[:bookmark_reminder], read: false, data: '{}')

      expect(user.unread_notifications).to eq(1)
    end
  end

  describe "#unread_high_priority_notifications" do
    fab!(:user) { Fabricate(:user) }

    it "only returns an unread count of PM and bookmark reminder notifications" do
      Notification.create!(user_id: user.id, notification_type: 1, read: false, data: '{}')
      Notification.create!(user_id: user.id, notification_type: Notification.types[:private_message], read: false, data: '{}')
      Notification.create!(user_id: user.id, notification_type: Notification.types[:bookmark_reminder], read: false, data: '{}')

      expect(user.unread_high_priority_notifications).to eq(2)
    end
  end

  describe "#unstage!" do
    let!(:user) { Fabricate(:staged, email: 'staged@account.com', active: true, username: 'staged1', name: 'Stage Name') }

    it "correctly unstages a user" do
      user.unstage!
      expect(user.staged).to eq(false)
    end

    it "removes all previous notifications during unstaging" do
      Fabricate(:notification, user: user)
      Fabricate(:private_message_notification, user: user)
      expect(user.total_unread_notifications).to eq(2)

      user.unstage!
      user.reload
      expect(user.total_unread_notifications).to eq(0)
      expect(user.staged).to eq(false)
    end

    it "triggers an event" do
      event = DiscourseEvent.track(:user_unstaged) { user.unstage! }
      expect(event).to be_present
      expect(event[:params].first).to eq(user)
    end
  end

  describe "#activate" do
    let!(:inactive) { Fabricate(:user, active: false) }

    it 'confirms email token and activates user' do
      inactive.activate
      inactive.reload
      expect(inactive.email_confirmed?).to eq(true)
      expect(inactive.active).to eq(true)
    end

    it 'works without needing to reload the model' do
      inactive.activate
      expect(inactive.email_confirmed?).to eq(true)
      expect(inactive.active).to eq(true)
    end

    it 'activates user even if email token is already confirmed' do
      token = inactive.email_tokens.find_by(email: inactive.email)
      token.update_column(:confirmed, true)
      inactive.activate
      expect(inactive.active).to eq(true)
    end
  end

  def filter_by(method)
    username = 'someuniqueusername'
    user.update!(username: username)

    username2 = 'awesomeusername'
    user2 = Fabricate(:user, username: username2)

    expect(User.public_send(method, username))
      .to eq([user])

    expect(User.public_send(method, 'UNiQuE'))
      .to eq([user])

    expect(User.public_send(method, [username, username2]))
      .to contain_exactly(user, user2)

    expect(User.public_send(method, ['UNiQuE', 'sOME']))
      .to contain_exactly(user, user2)
  end

  describe '#filter_by_username' do
    it 'should be able to filter by username' do
      filter_by(:filter_by_username)
    end
  end

  describe '#filter_by_username_or_email' do
    it 'should be able to filter by email' do
      email = 'veryspecialtest@discourse.org'
      user.update!(email: email)

      expect(User.filter_by_username_or_email(email))
        .to eq([user])

      expect(User.filter_by_username_or_email('veryspeCiaLtest'))
        .to eq([user])
    end

    it 'should be able to filter by username' do
      filter_by(:filter_by_username_or_email)
    end
  end

  describe "#secondary_emails" do
    fab!(:user) { Fabricate(:user) }

    it "only contains secondary emails" do
      expect(user.user_emails.secondary).to eq([])

      secondary_email = Fabricate(:secondary_email, user: user)

      expect(user.user_emails.secondary).to contain_exactly(secondary_email)
    end
  end

  describe "#email=" do
    let(:new_email) { "newprimary@example.com" }
    it 'sets the primary email' do
      user.update!(email: new_email)
      expect(User.find(user.id).email).to eq(new_email)
    end

    it 'only saves when save called' do
      old_email = user.email
      user.email = new_email
      expect(User.find(user.id).email).to eq(old_email)
      user.save!
      expect(User.find(user.id).email).to eq(new_email)
    end

    it 'will automatically remove matching secondary emails' do
      secondary_email_record = Fabricate(:secondary_email, user: user)
      user.reload
      expect(user.secondary_emails.count).to eq(1)
      user.email = secondary_email_record.email
      user.save!

      expect(User.find(user.id).email).to eq(secondary_email_record.email)
      expect(user.secondary_emails.count).to eq(0)
    end

  end

  describe "set_random_avatar" do
    it "sets a random avatar when selectable avatars is enabled" do
      avatar1 = Fabricate(:upload)
      avatar2 = Fabricate(:upload)
      SiteSetting.selectable_avatars = [avatar1, avatar2]
      SiteSetting.selectable_avatars_enabled = true

      user = Fabricate(:user)
      expect(user.uploaded_avatar_id).not_to be(nil)
      expect([avatar1.id, avatar2.id]).to include(user.uploaded_avatar_id)
      expect(user.user_avatar.custom_upload_id).to eq(user.uploaded_avatar_id)
    end
  end

  describe "ensure_consistency!" do

    it "will clean up dangling avatars" do
      upload = Fabricate(:upload)
      user = Fabricate(:user, uploaded_avatar_id: upload.id)

      upload.destroy!
      user.reload
      expect(user.uploaded_avatar_id).to eq(nil)

      user.update_columns(uploaded_avatar_id: upload.id)

      User.ensure_consistency!

      user.reload
      expect(user.uploaded_avatar_id).to eq(nil)
    end

  end

  describe '#match_primary_group_changes' do
    let(:group_a) { Fabricate(:group, title: 'A', users: [user]) }
    let(:group_b) { Fabricate(:group, title: 'B', users: [user]) }

    it "updates user's title only when it is blank or matches the previous primary group" do
      expect { user.update(primary_group: group_a) }.to change { user.reload.title }.from(nil).to('A')
      expect { user.update(primary_group: group_b) }.to change { user.reload.title }.from('A').to('B')

      user.update(title: 'Different')
      expect { user.update(primary_group: group_a) }.to_not change { user.reload.title }
    end

    it "updates user's title only when it is blank or matches the previous primary group" do
      expect { user.update(primary_group: group_a) }.to change { user.reload.flair_group }.from(nil).to(group_a)
      expect { user.update(primary_group: group_b) }.to change { user.reload.flair_group }.from(group_a).to(group_b)

      user.update(flair_group: group_a)
      expect { user.update(primary_group: group_a) }.to_not change { user.reload.flair_group }
    end
  end

  describe '#title=' do
    fab!(:badge) { Fabricate(:badge, name: 'Badge', allow_title: false) }

    it 'sets badge_granted_title correctly' do
      BadgeGranter.grant(badge, user)

      user.update!(title: badge.name)
      expect(user.user_profile.reload.badge_granted_title).to eq(false)

      user.update!(title: 'Custom')
      expect(user.user_profile.reload.badge_granted_title).to eq(false)

      badge.update!(allow_title: true)
      user.badges.reload
      user.update!(title: badge.name)
      expect(user.user_profile.reload.badge_granted_title).to eq(true)
      expect(user.user_profile.reload.granted_title_badge_id).to eq(badge.id)

      user.update!(title: nil)
      expect(user.user_profile.reload.badge_granted_title).to eq(false)
      expect(user.user_profile.granted_title_badge_id).to eq(nil)
    end

    context 'when a custom badge name has been set and it matches the title' do
      let(:customized_badge_name) { 'Merit Badge' }

      before do
        TranslationOverride.upsert!(I18n.locale, Badge.i18n_key(badge.name), customized_badge_name)
      end

      it 'sets badge_granted_title correctly' do
        BadgeGranter.grant(badge, user)

        badge.update!(allow_title: true)
        user.update!(title: customized_badge_name)
        expect(user.user_profile.reload.badge_granted_title).to eq(true)
        expect(user.user_profile.reload.granted_title_badge_id).to eq(badge.id)
      end

      after do
        TranslationOverride.revert!(I18n.locale, Badge.i18n_key(badge.name))
      end
    end
  end

  describe '#next_best_title' do
    fab!(:group_a) { Fabricate(:group, title: 'Group A') }
    fab!(:group_b) { Fabricate(:group, title: 'Group B') }
    fab!(:group_c) { Fabricate(:group, title: 'Group C') }
    fab!(:badge) { Fabricate(:badge, name: 'Badge', allow_title: true) }

    it 'only includes groups with title' do
      group_a.add(user)
      expect(user.next_best_title).to eq('Group A')

      group_a.update!(title: nil)
      expect(user.next_best_title).to eq(nil)
    end

    it 'only includes badges that allow to be set as title' do
      BadgeGranter.grant(badge, user)
      expect(user.next_best_title).to eq('Badge')

      badge.update!(allow_title: false)
      expect(user.next_best_title).to eq(nil)
    end

    it "picks the next best title in the order: user's primary group, primary group, groups, and badges" do
      group_a.add(user)
      group_b.add(user)
      group_c.add(user)
      BadgeGranter.grant(badge, user)

      group_a.update!(primary_group: true)
      group_b.update!(primary_group: true)
      user.update!(primary_group_id: group_a.id)
      expect(user.next_best_title).to eq('Group A')

      user.update!(primary_group_id: group_b.id)
      expect(user.next_best_title).to eq('Group B')

      group_b.remove(user)
      expect(user.next_best_title).to eq('Group A')

      group_a.remove(user)
      expect(user.next_best_title).to eq('Group C')

      group_c.remove(user)
      expect(user.next_best_title).to eq('Badge')

      BadgeGranter.revoke(UserBadge.find_by(user_id: user.id, badge_id: badge.id))
      expect(user.next_best_title).to eq(nil)
    end
  end

  describe 'check_site_contact_username' do
    before { SiteSetting.site_contact_username = contact_user.username }

    context 'admin' do
      let(:contact_user) { Fabricate(:admin) }

      it 'clears site_contact_username site setting when admin privilege is revoked' do
        contact_user.revoke_admin!
        expect(SiteSetting.site_contact_username).to eq(SiteSetting.defaults[:site_contact_username])
      end
    end

    context 'moderator' do
      let(:contact_user) { Fabricate(:moderator) }

      it 'clears site_contact_username site setting when moderator privilege is revoked' do
        contact_user.revoke_moderation!
        expect(SiteSetting.site_contact_username).to eq(SiteSetting.defaults[:site_contact_username])
      end
    end

    context 'admin and moderator' do
      let(:contact_user) { Fabricate(:moderator, admin: true) }

      it 'does not change site_contact_username site setting when admin privilege is revoked' do
        contact_user.revoke_admin!
        expect(SiteSetting.site_contact_username).to eq(contact_user.username)
      end

      it 'does not change site_contact_username site setting when moderator privilege is revoked' do
        contact_user.revoke_moderation!
        expect(SiteSetting.site_contact_username).to eq(contact_user.username)
      end

      it 'clears site_contact_username site setting when staff privileges are revoked' do
        contact_user.revoke_admin!
        contact_user.revoke_moderation!
        expect(SiteSetting.site_contact_username).to eq(SiteSetting.defaults[:site_contact_username])
      end
    end
  end

  context "#destroy!" do
    it 'clears up associated data on destroy!' do
      user = Fabricate(:user)
      post = Fabricate(:post)

      PostActionCreator.like(user, post)
      PostActionDestroyer.destroy(user, post, :like)

      UserAction.create!(user_id: user.id, action_type: UserAction::LIKE)
      UserAction.create!(user_id: -1, action_type: UserAction::LIKE, target_user_id: user.id)
      UserAction.create!(user_id: -1, action_type: UserAction::LIKE, acting_user_id: user.id)
      Developer.create!(user_id: user.id)

      user.reload

      user.destroy!

      expect(UserAction.where(user_id: user.id).length).to eq(0)
      expect(UserAction.where(target_user_id: user.id).length).to eq(0)
      expect(UserAction.where(acting_user_id: user.id).length).to eq(0)
      expect(PostAction.with_deleted.where(user_id: user.id).length).to eq(0)
      expect(Developer.where(user_id: user.id).length).to eq(0)
    end
  end

  context "human?" do
    it "returns true for a regular user" do
      expect(Fabricate(:user)).to be_human
    end

    it "returns false for the system user" do
      expect(Discourse.system_user).not_to be_human
    end
  end

  context "Unicode username" do
    before { SiteSetting.unicode_usernames = true }

    let(:user) { Fabricate(:user, username: "Lo\u0308we") } # NFD

    it "normalizes usernames" do
      expect(user.username).to eq("L\u00F6we") # NFC
      expect(user.username_lower).to eq("l\u00F6we") # NFC
    end

    describe ".username_exists?" do
      it "normalizes username before executing query" do
        expect(User.username_exists?(user.username)).to eq(true)
        expect(User.username_exists?("Lo\u0308we")).to eq(true) # NFD
        expect(User.username_exists?("L\u00F6we")).to eq(true)  # NFC
        expect(User.username_exists?("LO\u0308WE")).to eq(true) # NFD
        expect(User.username_exists?("l\u00D6wE")).to eq(true)  # NFC
        expect(User.username_exists?("foo")).to eq(false)
      end
    end

    describe ".system_avatar_template" do
      context "with external system avatars enabled" do
        before { SiteSetting.external_system_avatars_enabled = true }

        it "uses the normalized username" do
          expect(User.system_avatar_template("Lo\u0308we")).to match(%r|/letter_avatar_proxy/v\d/letter/l/71e660/{size}.png|)
          expect(User.system_avatar_template("L\u00F6wE")).to match(%r|/letter_avatar_proxy/v\d/letter/l/71e660/{size}.png|)
        end

        it "uses the first grapheme cluster and URL encodes it" do
          expect(User.system_avatar_template("बहुत")).to match(%r|/letter_avatar_proxy/v\d/letter/%E0%A4%AC/ea5d25/{size}.png|)
        end

        it "substitutes {username} with the URL encoded username" do
          SiteSetting.external_system_avatars_url = "https://{hostname}/{username}.png"
          expect(User.system_avatar_template("बहुत")).to eq("https://#{Discourse.current_hostname}/%E0%A4%AC%E0%A4%B9%E0%A5%81%E0%A4%A4.png")
        end
      end
    end
  end

  describe "Second-factor authenticators" do
    describe "#totps" do
      it "only includes enabled totp 2FA" do
        enabled_totp_2fa = Fabricate(:user_second_factor_totp, user: user, name: 'Enabled TOTP', enabled: true)
        disabled_totp_2fa = Fabricate(:user_second_factor_totp, user: user, name: 'Disabled TOTP', enabled: false)

        expect(user.totps.map(&:id)).to eq([enabled_totp_2fa.id])
      end
    end

    describe "#security_keys" do
      it "only includes enabled security_key 2FA" do
        enabled_security_key_2fa = Fabricate(:user_security_key_with_random_credential, user: user, name: 'Enabled YubiKey', enabled: true)
        disabled_security_key_2fa = Fabricate(:user_security_key_with_random_credential, user: user, name: 'Disabled YubiKey', enabled: false)

        expect(user.security_keys.map(&:id)).to eq([enabled_security_key_2fa.id])
      end
    end
  end

  describe 'Secure identifier for a user which is a string other than the ID used to identify the user in some cases e.g. security keys' do
    describe '#create_or_fetch_secure_identifier' do
      context 'if the user already has a secure identifier' do
        let(:sec_ident) { SecureRandom.hex(20) }
        before do
          user.update(secure_identifier: sec_ident)
        end

        it 'returns the identifier' do
          expect(user.create_or_fetch_secure_identifier).to eq(sec_ident)
        end
      end

      context 'if the user already does not have a secure identifier' do
        it 'creates one' do
          expect(user.secure_identifier).to eq(nil)
          user.create_or_fetch_secure_identifier
          expect(user.reload.secure_identifier).not_to eq(nil)
        end
      end
    end
  end

  describe 'Granting admin or moderator status' do
    fab!(:reviewable_user) { Fabricate(:reviewable_user) }

    it 'approves the associated reviewable when granting admin status' do
      reviewable_user.target.grant_admin!

      expect(reviewable_user.reload.status).to eq Reviewable.statuses[:approved]
    end

    it 'does nothing when the user is already approved' do
      reviewable_user = Fabricate(:reviewable_user)
      reviewable_user.perform(Discourse.system_user, :approve_user)

      reviewable_user.target.grant_admin!

      expect(reviewable_user.reload.status).to eq Reviewable.statuses[:approved]
    end

    it 'approves the associated reviewable when granting moderator status' do
      reviewable_user.target.grant_moderation!

      expect(reviewable_user.reload.status).to eq Reviewable.statuses[:approved]
    end

    it 'approves the user if there is no reviewable' do
      user = Fabricate(:user, approved: false)

      user.grant_admin!

      expect(user.approved).to eq(true)
    end
  end

  describe "#recent_time_read" do
    fab!(:user) { Fabricate(:user) }
    fab!(:user2) { Fabricate(:user) }

    before_all do
      UserVisit.create(user_id: user.id, visited_at: 1.minute.ago, posts_read: 1, mobile: false, time_read: 10)
      UserVisit.create(user_id: user.id, visited_at: 2.days.ago, posts_read: 1, mobile: false, time_read: 20)
      UserVisit.create(user_id: user.id, visited_at: 1.week.ago, posts_read: 1, mobile: false, time_read: 30)
      UserVisit.create(user_id: user.id, visited_at: 1.year.ago, posts_read: 1, mobile: false, time_read: 40) # Old, should be ignored
      UserVisit.create(user_id: user2.id, visited_at: 1.minute.ago, posts_read: 1, mobile: false, time_read: 50)
    end

    it "calculates correctly" do
      expect(user.recent_time_read).to eq(60)
      expect(user2.recent_time_read).to eq(50)
    end

    it "preloads correctly" do
      User.preload_recent_time_read([user, user2])

      expect(user.instance_variable_get(:@recent_time_read)).to eq(60)
      expect(user2.instance_variable_get(:@recent_time_read)).to eq(50)

      expect(user.recent_time_read).to eq(60)
      expect(user2.recent_time_read).to eq(50)
    end
  end

  def reset_last_seen_cache!(user)
    Discourse.redis.del("user:#{user.id}:#{Time.zone.now.to_date}")
  end

  describe ".encoded_username" do
    it "doesn't encoded ASCII usernames" do
      user = Fabricate(:user, username: "John")
      expect(user.encoded_username).to eq("John")
      expect(user.encoded_username(lower: true)).to eq("john")
    end

    it "encodes Unicode characters" do
      SiteSetting.unicode_usernames = true
      user = Fabricate(:user, username: "Löwe")
      expect(user.encoded_username).to eq("L%C3%B6we")
      expect(user.encoded_username(lower: true)).to eq("l%C3%B6we")
    end
  end

  describe '#update_ip_address!' do
    it 'updates ip_address correctly' do
      expect do
        user.update_ip_address!('127.0.0.1')
      end.to change { user.reload.ip_address.to_s }.to('127.0.0.1')

      expect do
        user.update_ip_address!('127.0.0.1')
      end.to_not change { user.reload.ip_address }
    end

    describe 'keeping old ip address' do
      before do
        SiteSetting.keep_old_ip_address_count = 2
      end

      it 'tracks old user record correctly' do
        expect do
          user.update_ip_address!('127.0.0.1')
        end.to change { UserIpAddressHistory.where(user_id: user.id).count }.by(1)

        freeze_time 10.minutes.from_now

        expect do
          user.update_ip_address!('0.0.0.0')
        end.to change { UserIpAddressHistory.where(user_id: user.id).count }.by(1)

        freeze_time 11.minutes.from_now

        expect do
          user.update_ip_address!('127.0.0.1')
        end.to_not change { UserIpAddressHistory.where(user_id: user.id).count }

        expect(UserIpAddressHistory.find_by(
          user_id: user.id, ip_address: '127.0.0.1'
        ).updated_at).to eq_time(Time.zone.now)

        freeze_time 12.minutes.from_now

        expect do
          user.update_ip_address!('0.0.0.1')
        end.to change { UserIpAddressHistory.where(user_id: user.id).count }.by(0)

        expect(
          UserIpAddressHistory.where(user_id: user.id).pluck(:ip_address).map(&:to_s)
        ).to eq(['127.0.0.1', '0.0.0.1'])
      end
    end
  end

  describe "#do_not_disturb?" do
    it "is true when a dnd timing is present for the current time" do
      Fabricate(:do_not_disturb_timing, user: user, starts_at: Time.zone.now, ends_at: 1.day.from_now)
      expect(user.do_not_disturb?).to eq(true)
    end

    it "is false when no dnd timing is present for the current time" do
      Fabricate(:do_not_disturb_timing, user: user, starts_at: Time.zone.now - 2.day, ends_at: 1.minute.ago)
      expect(user.do_not_disturb?).to eq(false)
    end
  end

  describe "#invited_by" do
    it 'returns even if invites was trashed' do
      invite = Fabricate(:invite, invited_by: Fabricate(:user))
      Fabricate(:invited_user, invite: invite, user: user)
      invite.trash!

      expect(user.invited_by).to eq(invite.invited_by)
    end
  end

  describe "#username_equals_to?" do
    [
      ["returns true for equal usernames", "john", "john", true],
      ["returns false for different usernames", "john", "bill", false],
      ["considers usernames that are different only in case as equal", "john", "JoHN", true]
    ].each do |testcase_name, current_username, another_username, is_equal|
      it "#{testcase_name}" do
        user = Fabricate(:user, username: current_username)
        result = user.username_equals_to?(another_username)

        expect(result).to be(is_equal)
      end
    end

    it "considers usernames that are equal after unicode normalization as equal" do
      SiteSetting.unicode_usernames = true

      raw = "Lo\u0308we" # Löwe, u0308 stands for ¨, so o\u0308 adds up to ö
      normalized = "l\u00F6we" # Löwe normilized, \u00F6 stands for ö
      user = Fabricate(:user, username: normalized)
      result = user.username_equals_to?(raw)

      expect(result).to be(true)
    end
  end
end
