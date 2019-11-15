# frozen_string_literal: true

require "rails_helper"

describe DiscourseSingleSignOn do
  before do
    @sso_url = "http://example.com/discourse_sso"
    @sso_secret = "shjkfdhsfkjh"

    SiteSetting.sso_url = @sso_url
    SiteSetting.enable_sso = true
    SiteSetting.sso_secret = @sso_secret
    Jobs.run_immediately!
  end

  def make_sso
    sso = SingleSignOn.new
    sso.sso_url = "http://meta.discorse.org/topics/111"
    sso.sso_secret = "supersecret"
    sso.nonce = "testing"
    sso.email = "some@email.com"
    sso.username = "sam"
    sso.name = "sam saffron"
    sso.external_id = "100"
    sso.avatar_url = "https://cdn.discourse.org/user_avatar.png"
    sso.avatar_force_update = false
    sso.bio = "about"
    sso.admin = false
    sso.moderator = false
    sso.suppress_welcome_message = false
    sso.require_activation = false
    sso.title = "user title"
    sso.custom_fields["a"] = "Aa"
    sso.custom_fields["b.b"] = "B.b"
    sso.website = "https://www.discourse.org/"
    sso
  end

  def test_parsed(parsed, sso)
    expect(parsed.nonce).to eq sso.nonce
    expect(parsed.email).to eq sso.email
    expect(parsed.username).to eq sso.username
    expect(parsed.name).to eq sso.name
    expect(parsed.external_id).to eq sso.external_id
    expect(parsed.avatar_url).to eq sso.avatar_url
    expect(parsed.avatar_force_update).to eq sso.avatar_force_update
    expect(parsed.bio).to eq sso.bio
    expect(parsed.admin).to eq sso.admin
    expect(parsed.moderator).to eq sso.moderator
    expect(parsed.suppress_welcome_message).to eq sso.suppress_welcome_message
    expect(parsed.require_activation).to eq false
    expect(parsed.title).to eq sso.title
    expect(parsed.custom_fields["a"]).to eq "Aa"
    expect(parsed.custom_fields["b.b"]).to eq "B.b"
    expect(parsed.website).to eq sso.website
  end

  it "can do round trip parsing correctly" do
    sso = SingleSignOn.new
    sso.sso_secret = "test"
    sso.name = "sam saffron"
    sso.username = "sam"
    sso.email = "sam@sam.com"

    sso = SingleSignOn.parse(sso.payload, "test")

    expect(sso.name).to eq "sam saffron"
    expect(sso.username).to eq "sam"
    expect(sso.email).to eq "sam@sam.com"
  end

  let(:ip_address) { "127.0.0.1" }

  it "bans bad external id" do
    sso = DiscourseSingleSignOn.new
    sso.username = "test"
    sso.name = ""
    sso.email = "test@test.com"
    sso.suppress_welcome_message = true

    sso.external_id = "    "

    expect do
      sso.lookup_or_create_user(ip_address)
    end.to raise_error(DiscourseSingleSignOn::BlankExternalId)

    sso.external_id = nil

    expect do
      sso.lookup_or_create_user(ip_address)
    end.to raise_error(DiscourseSingleSignOn::BlankExternalId)

    # going for slight duplication here so our intent is crystal clear
    %w{none nil Blank null}.each do |word|
      sso.external_id = word
      expect do
        sso.lookup_or_create_user(ip_address)
      end.to raise_error(DiscourseSingleSignOn::BannedExternalId)
    end
  end

  it "can lookup or create user when name is blank" do
    sso = DiscourseSingleSignOn.new
    sso.username = "test"
    sso.name = ""
    sso.email = "test@test.com"
    sso.external_id = "A"
    sso.suppress_welcome_message = true
    user = sso.lookup_or_create_user(ip_address)

    expect(user.persisted?).to eq(true)
  end

  it "unstaged users" do
    SiteSetting.sso_overrides_name = true

    email = "staged@user.com"
    Fabricate(:user, staged: true, email: email)

    sso = DiscourseSingleSignOn.new
    sso.username = "staged"
    sso.name = "Bob O'Bob"
    sso.email = email
    sso.external_id = "B"
    user = sso.lookup_or_create_user(ip_address)

    user.reload

    expect(user).to_not be_nil
    expect(user.staged).to be(false)

    expect(user.name).to eq("Bob O'Bob")
  end

  context "reviewables" do
    let(:sso) do
      DiscourseSingleSignOn.new.tap do |sso|
        sso.username = "staged"
        sso.name = "Bob O'Bob"
        sso.email = "bob@obob.com"
        sso.external_id = "B"
      end
    end

    it "doesn't create reviewables if we aren't approving users" do
      user = sso.lookup_or_create_user(ip_address)
      reviewable = ReviewableUser.find_by(target: user)
      expect(reviewable).to be_blank
    end

    it "creates reviewables if needed" do
      SiteSetting.must_approve_users = true
      user = sso.lookup_or_create_user(ip_address)
      reviewable = ReviewableUser.find_by(target: user)
      expect(reviewable).to be_present
      expect(reviewable).to be_pending
    end
  end

  it "can set admin and moderator" do
    admin_group = Group[:admins]
    mod_group = Group[:moderators]
    staff_group = Group[:staff]

    sso = DiscourseSingleSignOn.new
    sso.username = "misteradmin"
    sso.name = "Bob Admin"
    sso.email = "admin@admin.com"
    sso.external_id = "id"
    sso.admin = true
    sso.moderator = true
    sso.suppress_welcome_message = true

    user = sso.lookup_or_create_user(ip_address)
    staff_group.reload

    expect(mod_group.users.where('users.id = ?', user.id).exists?).to eq(true)
    expect(staff_group.users.where('users.id = ?', user.id).exists?).to eq(true)
    expect(admin_group.users.where('users.id = ?', user.id).exists?).to eq(true)
  end

  it "can force a list of groups with the groups attribute" do
    user = Fabricate(:user)
    group1 = Fabricate(:group, name: 'group1')
    group2 = Fabricate(:group, name: 'group2')

    sso = DiscourseSingleSignOn.new
    sso.username = "bobsky"
    sso.name = "Bob"
    sso.email = user.email
    sso.external_id = "A"

    sso.groups = "#{group2.name.capitalize},group4,badname,trust_level_4"
    sso.lookup_or_create_user(ip_address)

    SiteSetting.sso_overrides_groups = true

    group1.reload
    expect(group1.usernames).to eq("")
    expect(group2.usernames).to eq("")

    group1.add(user)
    group1.save

    sso.lookup_or_create_user(ip_address)
    expect(group1.usernames).to eq("")
    expect(group2.usernames).to eq(user.username)

    sso.groups = "badname,trust_level_4"
    sso.lookup_or_create_user(ip_address)
    expect(group1.usernames).to eq("")
    expect(group2.usernames).to eq("")
  end

  it "can specify groups" do

    user = Fabricate(:user)

    add_group1 = Fabricate(:group, name: 'group1')
    add_group2 = Fabricate(:group, name: 'group2')
    existing_group = Fabricate(:group, name: 'group3')
    add_group4 = Fabricate(:group, name: 'GROUP4')
    existing_group2 = Fabricate(:group, name: 'GRoup5')

    [existing_group, existing_group2].each do |g|
      g.add(user)
      g.save!
    end

    add_group1.add(user)
    existing_group.save!

    sso = DiscourseSingleSignOn.new
    sso.username = "bobsky"
    sso.name = "Bob"
    sso.email = user.email
    sso.external_id = "A"

    sso.add_groups = "#{add_group1.name},#{add_group2.name.capitalize},group4,badname"
    sso.remove_groups = "#{existing_group.name},#{existing_group2.name.downcase},badname"

    sso.lookup_or_create_user(ip_address)

    existing_group.reload
    expect(existing_group.usernames).to eq("")

    existing_group2.reload
    expect(existing_group2.usernames).to eq("")

    add_group1.reload
    expect(add_group1.usernames).to eq(user.username)

    add_group2.reload
    expect(add_group2.usernames).to eq(user.username)

    add_group4.reload
    expect(add_group4.usernames).to eq(user.username)
  end

  it 'can override username properly when only the case changes' do
    SiteSetting.sso_overrides_username = true

    sso = DiscourseSingleSignOn.new
    sso.username = "testuser"
    sso.name = "test user"
    sso.email = "test@test.com"
    sso.external_id = "100"
    sso.bio = "This **is** the bio"
    sso.suppress_welcome_message = true

    # create the original user
    user = sso.lookup_or_create_user(ip_address)
    expect(user.username).to eq "testuser"

    # change the username case
    sso.username = "TestUser"
    user = sso.lookup_or_create_user(ip_address)
    expect(user.username).to eq "TestUser"
  end

  it 'behaves properly when sso_overrides_username is set but username is missing or blank' do
    SiteSetting.sso_overrides_username = true

    sso = DiscourseSingleSignOn.new
    sso.username = "testuser"
    sso.name = "test user"
    sso.email = "test@test.com"
    sso.external_id = "100"
    sso.bio = "This **is** the bio"
    sso.suppress_welcome_message = true

    # create the original user
    user = sso.lookup_or_create_user(ip_address)
    expect(user.username).to eq "testuser"

    # remove username from payload
    sso.username = nil
    user = sso.lookup_or_create_user(ip_address)
    expect(user.username).to eq "testuser"

    # set username in payload to blank
    sso.username = ''
    user = sso.lookup_or_create_user(ip_address)
    expect(user.username).to eq "testuser"
  end

  it "can override name / email / username" do
    admin = Fabricate(:admin)

    SiteSetting.email_editable = false
    SiteSetting.sso_overrides_name = true
    SiteSetting.sso_overrides_email = true
    SiteSetting.sso_overrides_username = true

    sso = DiscourseSingleSignOn.new
    sso.username = "bob%the$admin"
    sso.name = "Bob Admin"
    sso.email = admin.email
    sso.external_id = "A"

    sso.lookup_or_create_user(ip_address)

    admin.reload

    expect(admin.name).to eq "Bob Admin"
    expect(admin.username).to eq "bob_the_admin"
    expect(admin.email).to eq admin.email

    sso.email = "TEST@bob.com"

    sso.name = "Louis C.K."

    sso.lookup_or_create_user(ip_address)

    admin.reload

    expect(admin.email).to eq("test@bob.com")
    expect(admin.username).to eq "bob_the_admin"
    expect(admin.name).to eq "Louis C.K."
  end

  it "can fill in data on way back" do
    sso = make_sso

    url, payload = sso.to_url.split("?")
    expect(url).to eq sso.sso_url
    parsed = SingleSignOn.parse(payload, "supersecret")

    test_parsed(parsed, sso)
  end

  it "handles sso_url with query params" do
    sso = make_sso
    sso.sso_url = "http://tcdev7.wpengine.com/?action=showlogin"

    expect(sso.to_url.split('?').size).to eq 2

    url, payload = sso.to_url.split("?")
    expect(url).to eq "http://tcdev7.wpengine.com/"
    parsed = SingleSignOn.parse(payload, "supersecret")

    test_parsed(parsed, sso)
  end

  it "validates nonce" do
    _ , payload = DiscourseSingleSignOn.generate_url.split("?")

    sso = DiscourseSingleSignOn.parse(payload)
    expect(sso.nonce_valid?).to eq true

    sso.expire_nonce!

    expect(sso.nonce_valid?).to eq false

  end

  it "generates a correct sso url" do
    url, payload = DiscourseSingleSignOn.generate_url.split("?")
    expect(url).to eq @sso_url

    sso = DiscourseSingleSignOn.parse(payload)
    expect(sso.nonce).to_not be_nil
  end

  context 'user locale' do
    it 'sets default user locale if specified' do
      SiteSetting.allow_user_locale = true

      sso = DiscourseSingleSignOn.new
      sso.username = "test"
      sso.name = "test"
      sso.email = "test@test.com"
      sso.external_id = "123"
      sso.locale = "es"

      user = sso.lookup_or_create_user(ip_address)

      expect(user.locale).to eq("es")

      user.update_column(:locale, "he")

      user = sso.lookup_or_create_user(ip_address)
      expect(user.locale).to eq("he")

      sso.locale_force_update = true
      user = sso.lookup_or_create_user(ip_address)
      expect(user.locale).to eq("es")

      sso.locale = "fake"
      user = sso.lookup_or_create_user(ip_address)
      expect(user.locale).to eq("es")
    end
  end

  context 'trusting emails' do
    let(:sso) do
      sso = DiscourseSingleSignOn.new
      sso.username = "test"
      sso.name = "test"
      sso.email = "test@example.com"
      sso.external_id = "A"
      sso.suppress_welcome_message = true
      sso
    end

    it 'activates users by default' do
      user = sso.lookup_or_create_user(ip_address)
      expect(user.active).to eq(true)
    end

    it 'does not activate user when asked not to' do
      sso.require_activation = true
      user = sso.lookup_or_create_user(ip_address)
      expect(user.active).to eq(false)

      user.activate

      sso.external_id = "B"

      expect do
        sso.lookup_or_create_user(ip_address)
      end.to raise_error(ActiveRecord::RecordInvalid)

    end

    it 'does not deactivate user if email provided is capitalized' do
      SiteSetting.email_editable = false
      SiteSetting.sso_overrides_email = true
      sso.require_activation = true

      user = sso.lookup_or_create_user(ip_address)
      expect(user.active).to eq(false)

      user.update_columns(active: true)
      user = sso.lookup_or_create_user(ip_address)
      expect(user.active).to eq(true)

      sso.email = "Test@example.com"
      user = sso.lookup_or_create_user(ip_address)
      expect(user.active).to eq(true)
    end

    it 'deactivates accounts that have updated email address' do

      SiteSetting.email_editable = false
      SiteSetting.sso_overrides_email = true
      sso.require_activation = true

      user = sso.lookup_or_create_user(ip_address)
      expect(user.active).to eq(false)

      old_email = user.email

      user.update_columns(active: true)
      user = sso.lookup_or_create_user(ip_address)
      expect(user.active).to eq(true)

      user.primary_email.update_columns(email: 'xXx@themovie.com')

      user = sso.lookup_or_create_user(ip_address)
      expect(user.email).to eq(old_email)
      expect(user.active).to eq(false)

    end

  end

  context 'welcome emails' do
    let(:sso) {
      sso = DiscourseSingleSignOn.new
      sso.username = "test"
      sso.name = "test"
      sso.email = "test@example.com"
      sso.external_id = "A"
      sso
    }

    it "sends a welcome email by default" do
      User.any_instance.expects(:enqueue_welcome_message).once
      _user = sso.lookup_or_create_user(ip_address)
    end

    it "suppresses the welcome email when asked to" do
      User.any_instance.expects(:enqueue_welcome_message).never
      sso.suppress_welcome_message = true
      _user = sso.lookup_or_create_user(ip_address)
    end
  end

  context 'setting title for a user' do
    let(:sso) {
      sso = DiscourseSingleSignOn.new
      sso.username = 'test'
      sso.name = 'test'
      sso.email = 'test@test.com'
      sso.external_id = '100'
      sso.title = "The User's Title"
      sso
    }

    it 'sets title correctly' do
      user = sso.lookup_or_create_user(ip_address)
      expect(user.title).to eq(sso.title)

      sso.title = "farmer"
      user = sso.lookup_or_create_user(ip_address)

      expect(user.title).to eq("farmer")

      sso.title = nil
      user = sso.lookup_or_create_user(ip_address)

      expect(user.title).to eq("farmer")
    end
  end

  context 'setting bio for a user' do
    let(:sso) do
      sso = DiscourseSingleSignOn.new
      sso.username = "test"
      sso.name = "test"
      sso.email = "test@test.com"
      sso.external_id = "100"
      sso.bio = "This **is** the bio"
      sso.suppress_welcome_message = true
      sso
    end

    it 'can set bio if supplied on new users or users with empty bio' do
      # new account
      user = sso.lookup_or_create_user(ip_address)
      expect(user.user_profile.bio_cooked).to match_html("<p>This <strong>is</strong> the bio</p>")

      # no override by default
      sso.bio = "new profile"
      user = sso.lookup_or_create_user(ip_address)

      expect(user.user_profile.bio_cooked).to match_html("<p>This <strong>is</strong> the bio</p>")

      # yes override for blank
      user.user_profile.update!(bio_raw: '')

      user = sso.lookup_or_create_user(ip_address)
      expect(user.user_profile.bio_cooked).to match_html("<p>new profile</p>")

      # yes override if site setting
      sso.bio = "new profile 2"
      SiteSetting.sso_overrides_bio = true

      user = sso.lookup_or_create_user(ip_address)
      expect(user.user_profile.bio_cooked).to match_html("<p>new profile 2</p")
    end

  end

  context 'when sso_overrides_avatar is not enabled' do

    it "correctly handles provided avatar_urls" do
      sso = DiscourseSingleSignOn.new
      sso.external_id = 666
      sso.email = "sam@sam.com"
      sso.name = "sam"
      sso.username = "sam"
      sso.avatar_url = "http://awesome.com/image.png"
      sso.suppress_welcome_message = true

      FileHelper.stubs(:download).returns(file_from_fixtures("logo.png"), file_from_fixtures("logo.png"))
      user = sso.lookup_or_create_user(ip_address)
      user.reload
      avatar_id = user.uploaded_avatar_id

      # initial creation ...
      expect(avatar_id).to_not eq(nil)

      # junk avatar id should be updated
      old_id = user.uploaded_avatar_id
      Upload.destroy(old_id)
      FileHelper.stubs(:download).returns(file_from_fixtures("logo.png"), file_from_fixtures("logo.png"))
      user = sso.lookup_or_create_user(ip_address)
      user.reload
      avatar_id = user.uploaded_avatar_id

      expect(avatar_id).to_not eq(nil)
      expect(old_id).to_not eq(avatar_id)

      # FileHelper.stubs(:download) { raise "should not be called" }
      # sso.avatar_url = "https://some.new/avatar.png"
      # user = sso.lookup_or_create_user(ip_address)
      # user.reload
      #
      # # avatar updated but no override specified ...
      # expect(user.uploaded_avatar_id).to eq(avatar_id)
      #
      # sso.avatar_force_update = true
      # FileHelper.stubs(:download).returns(file_from_fixtures("logo-dev.png"))
      # user = sso.lookup_or_create_user(ip_address)
      # user.reload
      #
      # # we better have a new avatar
      # expect(user.uploaded_avatar_id).not_to eq(avatar_id)
      # expect(user.uploaded_avatar_id).not_to eq(nil)
      #
      # avatar_id = user.uploaded_avatar_id
      #
      # sso.avatar_force_update = true
      # FileHelper.stubs(:download) { raise "not found" }
      # user = sso.lookup_or_create_user(ip_address)
      # user.reload
      #
      # # we better have the same avatar
      # expect(user.uploaded_avatar_id).to eq(avatar_id)
    end

  end

  context 'when sso_overrides_avatar is enabled' do
    fab!(:sso_record) { Fabricate(:single_sign_on_record, external_avatar_url: "http://example.com/an_image.png") }

    let!(:sso) {
      sso = DiscourseSingleSignOn.new
      sso.username = "test"
      sso.name = "test"
      sso.email = sso_record.user.email
      sso.external_id = sso_record.external_id
      sso
    }

    let(:logo) { file_from_fixtures("logo.png") }

    before do
      SiteSetting.sso_overrides_avatar = true
    end

    it "deal with no avatar url passed for an existing user with an avatar" do
      Sidekiq::Testing.inline! do
        # Deliberately not setting avatar_url so it should not update
        sso_record.user.update_columns(uploaded_avatar_id: -1)
        user = sso.lookup_or_create_user(ip_address)
        user.reload

        expect(user).to_not be_nil
        expect(user.uploaded_avatar_id).to eq(-1)
      end
    end

    it "deal with no avatar_force_update passed as a boolean" do
      Sidekiq::Testing.inline! do
        FileHelper.stubs(:download).returns(logo)

        sso_record.user.update_columns(uploaded_avatar_id: -1)

        sso.avatar_url = "http://example.com/a_different_image.png"
        sso.avatar_force_update = false

        user = sso.lookup_or_create_user(ip_address)
        user.reload

        expect(user).to_not be_nil
        expect(user.uploaded_avatar_id).to_not eq(-1)
      end
    end
  end

  context 'when sso_overrides_profile_background is not enabled' do

    it "correctly handles provided profile_background_urls" do
      sso = DiscourseSingleSignOn.new
      sso.external_id = 666
      sso.email = "sam@sam.com"
      sso.name = "sam"
      sso.username = "sam"
      sso.profile_background_url = "http://awesome.com/image.png"
      sso.suppress_welcome_message = true

      FileHelper.stubs(:download).returns(file_from_fixtures("logo.png"))
      user = sso.lookup_or_create_user(ip_address)
      user.reload
      user.user_profile.reload
      profile_background_url = user.profile_background_upload.url

      # initial creation ...
      expect(profile_background_url).to_not eq(nil)
      expect(profile_background_url).to_not eq('')

      FileHelper.stubs(:download) { raise "should not be called" }
      sso.profile_background_url = "https://some.new/avatar.png"
      user = sso.lookup_or_create_user(ip_address)
      user.reload
      user.user_profile.reload

      # profile_background updated but no override specified ...
      expect(user.profile_background_upload.url).to eq(profile_background_url)
    end
  end

  context 'when sso_overrides_profile_background is enabled' do
    fab!(:sso_record) { Fabricate(:single_sign_on_record, external_profile_background_url: "http://example.com/an_image.png") }

    let!(:sso) {
      sso = DiscourseSingleSignOn.new
      sso.username = "test"
      sso.name = "test"
      sso.email = sso_record.user.email
      sso.external_id = sso_record.external_id
      sso
    }

    let(:logo) { file_from_fixtures("logo.png") }

    before do
      SiteSetting.sso_overrides_profile_background = true
    end

    it "deal with no profile_background_url passed for an existing user with a profile_background" do
      # Deliberately not setting profile_background_url so it should not update
      sso_record.user.user_profile.clear_profile_background
      user = sso.lookup_or_create_user(ip_address)
      user.reload

      expect(user.profile_background_upload).to eq(nil)
    end

    it "deal with a profile_background_url passed for an existing user with a profile_background" do
      url = "http://example.com/a_different_image.png"
      stub_request(:get, url).to_return(body: logo)

      sso_record.user.user_profile.clear_profile_background
      sso.profile_background_url = "http://example.com/a_different_image.png"
      user = sso.lookup_or_create_user(ip_address)
      user.reload

      expect(user.profile_background_upload).to_not eq(nil)
    end
  end

  context 'when sso_overrides_card_background is not enabled' do

    it "correctly handles provided card_background_urls" do
      sso = DiscourseSingleSignOn.new
      sso.external_id = 666
      sso.email = "sam@sam.com"
      sso.name = "sam"
      sso.username = "sam"
      sso.card_background_url = "http://awesome.com/image.png"
      sso.suppress_welcome_message = true
      FileHelper.stubs(:download).returns(file_from_fixtures("logo.png"))
      user = sso.lookup_or_create_user(ip_address)
      user.reload
      user.user_profile.reload
      card_background_url = user.user_profile.card_background_upload.url

      # initial creation ...
      expect(card_background_url).to be_present

      FileHelper.stubs(:download) { raise "should not be called" }
      sso.card_background_url = "https://some.new/avatar.png"
      user = sso.lookup_or_create_user(ip_address)
      user.reload
      user.user_profile.reload

      # card_background updated but no override specified ...
      expect(user.user_profile.card_background_upload.url).to eq(
        card_background_url
      )
    end
  end

  context 'when sso_overrides_card_background is enabled' do
    fab!(:sso_record) { Fabricate(:single_sign_on_record, external_card_background_url: "http://example.com/an_image.png") }

    let!(:sso) {
      sso = DiscourseSingleSignOn.new
      sso.username = "test"
      sso.name = "test"
      sso.email = sso_record.user.email
      sso.external_id = sso_record.external_id
      sso
    }

    let(:logo) { file_from_fixtures("logo.png") }

    before do
      SiteSetting.sso_overrides_card_background = true
    end

    it "deal with no card_background_url passed for an existing user with a card_background" do
      # Deliberately not setting card_background_url so it should not update
      sso_record.user.user_profile.clear_card_background
      user = sso.lookup_or_create_user(ip_address)
      user.reload

      expect(user.user_profile.card_background_upload).to eq(nil)
    end

    it "deal with a card_background_url passed for an existing user with a card_background_url" do
      url = "http://example.com/a_different_image.png"
      stub_request(:get, url).to_return(body: logo)

      sso_record.user.user_profile.clear_card_background
      sso.card_background_url = url

      user = sso.lookup_or_create_user(ip_address)
      user.reload

      expect(user.user_profile.card_background_upload.url).to_not eq('')
    end
  end

end
