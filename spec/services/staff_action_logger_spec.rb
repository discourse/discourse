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

  describe 'log_trust_level_change' do
    let(:user) { Fabricate(:user) }
    let(:old_trust_level) { TrustLevel.levels[:newuser] }
    let(:new_trust_level) { TrustLevel.levels[:basic] }

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
      max_level = TrustLevel.levels.values.max
      expect { logger.log_trust_level_change(user, old_trust_level, max_level + 1) }.to raise_error(Discourse::InvalidParameters)
    end

    it 'creates a new UserHistory record' do
      expect { log_trust_level_change }.to change { UserHistory.count }.by(1)
      UserHistory.last.details.should include "new trust level: #{new_trust_level}"
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
      log_record.subject.should == valid_params[:name]
      log_record.previous_value.should be_nil
      log_record.new_value.should be_present
      json = ::JSON.parse(log_record.new_value)
      json['stylesheet'].should be_present
      json['header'].should be_present
    end

    it "logs updated site customizations" do
      existing = SiteCustomization.new(name: 'Banana', stylesheet: "body {color: yellow;}", header: "h1 {color: brown;}")
      log_record = logger.log_site_customization_change(existing, valid_params)
      log_record.previous_value.should be_present
      json = ::JSON.parse(log_record.previous_value)
      json['stylesheet'].should == existing.stylesheet
      json['header'].should == existing.header
    end
  end

  describe "log_site_customization_destroy" do
    it "raises an error when params are invalid" do
      expect { logger.log_site_customization_destroy(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      site_customization = SiteCustomization.new(name: 'Banana', stylesheet: "body {color: yellow;}", header: "h1 {color: brown;}")
      log_record = logger.log_site_customization_destroy(site_customization)
      log_record.previous_value.should be_present
      log_record.new_value.should be_nil
      json = ::JSON.parse(log_record.previous_value)
      json['stylesheet'].should == site_customization.stylesheet
      json['header'].should == site_customization.header
    end
  end

  describe "log_user_ban" do
    let(:user) { Fabricate(:user) }

    it "raises an error when arguments are missing" do
      expect { logger.log_user_ban(nil, nil) }.to raise_error(Discourse::InvalidParameters)
      expect { logger.log_user_ban(nil, "He was bad.") }.to raise_error(Discourse::InvalidParameters)
    end

    it "reason arg is optional" do
      expect { logger.log_user_ban(user, nil) }.to_not raise_error
    end

    it "creates a new UserHistory record" do
      reason = "He was a big meanie."
      log_record = logger.log_user_ban(user, reason)
      log_record.should be_valid
      log_record.details.should == reason
      log_record.target_user.should == user
    end
  end

  describe "log_user_unban" do
    let(:user) { Fabricate(:user, banned_at: 1.day.ago, banned_till: 7.days.from_now) }

    it "raises an error when argument is missing" do
      expect { logger.log_user_unban(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      log_record = logger.log_user_unban(user)
      log_record.should be_valid
      log_record.target_user.should == user
    end
  end
end
