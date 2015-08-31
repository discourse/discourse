require 'spec_helper'

describe StaffActionLogger do

  let(:admin)  { Fabricate(:admin) }
  let(:logger) { described_class.new(admin) }

  describe 'new' do
    it 'raises an error when user is nil' do
      expect { described_class.new(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when user is not a User' do
      expect { described_class.new(5) }.to raise_error(Discourse::InvalidParameters)
    end
  end

  describe 'log_user_deletion' do
    let(:deleted_user) { Fabricate(:user) }

    subject(:log_user_deletion) { described_class.new(admin).log_user_deletion(deleted_user) }

    it 'raises an error when user is nil' do
      expect { logger.log_user_deletion(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when user is not a User' do
      expect { logger.log_user_deletion(1) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'creates a new UserHistory record' do
      expect { log_user_deletion }.to change { UserHistory.count }.by(1)
    end
  end

  describe "log_show_emails" do
    it "logs the user history" do
      expect { logger.log_show_emails([admin]) }.to change(UserHistory, :count).by(1)
    end

    it "doesn't raise an exception with nothing to log" do
      expect { logger.log_show_emails([]) }.not_to raise_error
    end

    it "doesn't raise an exception with nil input" do
      expect { logger.log_show_emails(nil) }.not_to raise_error
    end
  end

  describe 'log_post_deletion' do
    let(:deleted_post) { Fabricate(:post) }

    subject(:log_post_deletion) { described_class.new(admin).log_post_deletion(deleted_post) }

    it 'raises an error when post is nil' do
      expect { logger.log_post_deletion(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when post is not a Post' do
      expect { logger.log_post_deletion(1) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'creates a new UserHistory record' do
      expect { log_post_deletion }.to change { UserHistory.count }.by(1)
    end

    it 'does not explode if post does not have a user' do
      expect {
        deleted_post.update_columns(user_id: nil)
        log_post_deletion
      }.to change { UserHistory.count }.by(1)
    end
  end

  describe 'log_topic_deletion' do
    let(:deleted_topic) { Fabricate(:topic) }

    subject(:log_topic_deletion) { described_class.new(admin).log_topic_deletion(deleted_topic) }

    it 'raises an error when topic is nil' do
      expect { logger.log_topic_deletion(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when topic is not a Topic' do
      expect { logger.log_topic_deletion(1) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'creates a new UserHistory record' do
      expect { log_topic_deletion }.to change { UserHistory.count }.by(1)
    end
  end

  describe 'log_trust_level_change' do
    let(:user) { Fabricate(:user) }
    let(:old_trust_level) { TrustLevel[0] }
    let(:new_trust_level) { TrustLevel[1] }

    subject(:log_trust_level_change) { described_class.new(admin).log_trust_level_change(user, old_trust_level, new_trust_level) }

    it 'raises an error when user or trust level is nil' do
      expect { logger.log_trust_level_change(nil, old_trust_level, new_trust_level) }.to raise_error(Discourse::InvalidParameters)
      expect { logger.log_trust_level_change(user, nil, new_trust_level) }.to raise_error(Discourse::InvalidParameters)
      expect { logger.log_trust_level_change(user, old_trust_level, nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when user is not a User' do
      expect { logger.log_trust_level_change(1, old_trust_level, new_trust_level) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'raises an error when new trust level is not a Trust Level' do
      max_level = TrustLevel.valid_range.max
      expect { logger.log_trust_level_change(user, old_trust_level, max_level + 1) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'creates a new UserHistory record' do
      expect { log_trust_level_change }.to change { UserHistory.count }.by(1)
      expect(UserHistory.last.details).to include "new trust level: #{new_trust_level}"
    end
  end

  describe "log_site_setting_change" do
    it "raises an error when params are invalid" do
      SiteSetting.stubs(:respond_to?).with('abc').returns(false)
      expect { logger.log_site_setting_change(nil, '1', '2') }.to raise_error(Discourse::InvalidParameters)
      expect { logger.log_site_setting_change('abc', '1', '2') }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      expect { logger.log_site_setting_change('title', 'Discourse', 'My Site') }.to change { UserHistory.count }.by(1)
    end
  end

  describe "log_site_customization_change" do
    let(:valid_params) { {name: 'Cool Theme', stylesheet: "body {\n  background-color: blue;\n}\n", header: "h1 {color: white;}"} }

    it "raises an error when params are invalid" do
      expect { logger.log_site_customization_change(nil, nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "logs new site customizations" do
      log_record = logger.log_site_customization_change(nil, valid_params)
      expect(log_record.subject).to eq(valid_params[:name])
      expect(log_record.previous_value).to eq(nil)
      expect(log_record.new_value).to be_present
      json = ::JSON.parse(log_record.new_value)
      expect(json['stylesheet']).to be_present
      expect(json['header']).to be_present
    end

    it "logs updated site customizations" do
      existing = SiteCustomization.new(name: 'Banana', stylesheet: "body {color: yellow;}", header: "h1 {color: brown;}")
      log_record = logger.log_site_customization_change(existing, valid_params)
      expect(log_record.previous_value).to be_present
      json = ::JSON.parse(log_record.previous_value)
      expect(json['stylesheet']).to eq(existing.stylesheet)
      expect(json['header']).to eq(existing.header)
    end
  end

  describe "log_site_customization_destroy" do
    it "raises an error when params are invalid" do
      expect { logger.log_site_customization_destroy(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      site_customization = SiteCustomization.new(name: 'Banana', stylesheet: "body {color: yellow;}", header: "h1 {color: brown;}")
      log_record = logger.log_site_customization_destroy(site_customization)
      expect(log_record.previous_value).to be_present
      expect(log_record.new_value).to eq(nil)
      json = ::JSON.parse(log_record.previous_value)
      expect(json['stylesheet']).to eq(site_customization.stylesheet)
      expect(json['header']).to eq(site_customization.header)
    end
  end

  describe "log_user_suspend" do
    let(:user) { Fabricate(:user, suspended_at: 10.minutes.ago, suspended_till: 1.day.from_now) }

    it "raises an error when arguments are missing" do
      expect { logger.log_user_suspend(nil, nil) }.to raise_error(Discourse::InvalidParameters)
      expect { logger.log_user_suspend(nil, "He was bad.") }.to raise_error(Discourse::InvalidParameters)
    end

    it "reason arg is optional" do
      expect { logger.log_user_suspend(user, nil) }.to_not raise_error
    end

    it "creates a new UserHistory record" do
      reason = "He was a big meanie."
      log_record = logger.log_user_suspend(user, reason)
      expect(log_record).to be_valid
      expect(log_record.details).to eq(reason)
      expect(log_record.target_user).to eq(user)
    end
  end

  describe "log_user_unsuspend" do
    let(:user) { Fabricate(:user, suspended_at: 1.day.ago, suspended_till: 7.days.from_now) }

    it "raises an error when argument is missing" do
      expect { logger.log_user_unsuspend(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      log_record = logger.log_user_unsuspend(user)
      expect(log_record).to be_valid
      expect(log_record.target_user).to eq(user)
    end
  end

  describe "log_badge_grant" do
    let(:user) { Fabricate(:user) }
    let(:badge) { Fabricate(:badge) }
    let(:user_badge) { BadgeGranter.grant(badge, user) }

    it "raises an error when argument is missing" do
      expect { logger.log_badge_grant(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      log_record = logger.log_badge_grant(user_badge)
      expect(log_record).to be_valid
      expect(log_record.target_user).to eq(user)
      expect(log_record.details).to eq(badge.name)
    end
  end

  describe "log_badge_revoke" do
    let(:user) { Fabricate(:user) }
    let(:badge) { Fabricate(:badge) }
    let(:user_badge) { BadgeGranter.grant(badge, user) }

    it "raises an error when argument is missing" do
      expect { logger.log_badge_revoke(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      log_record = logger.log_badge_revoke(user_badge)
      expect(log_record).to be_valid
      expect(log_record.target_user).to eq(user)
      expect(log_record.details).to eq(badge.name)
    end
  end

  describe 'log_roll_up' do
    let(:subnets) { ["1.2.3.0/24", "42.42.42.0/24"] }
    subject(:log_roll_up) { described_class.new(admin).log_roll_up(subnets) }

    it 'creates a new UserHistory record' do
      log_record = logger.log_roll_up(subnets)
      expect(log_record).to be_valid
      expect(log_record.details).to eq(subnets.join(", "))
    end
  end

  describe 'log_custom' do
    it "raises an error when `custom_type` is missing" do
      expect { logger.log_custom(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates the UserHistory record" do
      logged = logger.log_custom('clicked_something', {
        evil: 'trout',
        clicked_on: 'thing',
        topic_id: 1234
      })
      expect(logged).to be_valid
      expect(logged.details).to eq("evil: trout\nclicked_on: thing")
      expect(logged.action).to eq(UserHistory.actions[:custom_staff])
      expect(logged.custom_type).to eq('clicked_something')
      expect(logged.topic_id).to be === 1234
    end
  end
end
