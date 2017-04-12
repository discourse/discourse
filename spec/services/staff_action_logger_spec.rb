require 'rails_helper'

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
      expect { logger.log_site_setting_change(nil, '1', '2') }.to raise_error(Discourse::InvalidParameters)
      expect { logger.log_site_setting_change('i_am_a_site_setting_that_will_never_exist', '1', '2') }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      expect { logger.log_site_setting_change('title', 'Discourse', 'My Site') }.to change { UserHistory.count }.by(1)
    end
  end

  describe "log_theme_change" do

    it "raises an error when params are invalid" do
      expect { logger.log_theme_change(nil, nil) }.to raise_error(Discourse::InvalidParameters)
    end

    let :theme do
      Theme.new(name: 'bob', user_id: -1)
    end

    it "logs new site customizations" do

      log_record = logger.log_theme_change(nil, theme)
      expect(log_record.subject).to eq(theme.name)
      expect(log_record.previous_value).to eq(nil)
      expect(log_record.new_value).to be_present

      json = ::JSON.parse(log_record.new_value)
      expect(json['name']).to eq(theme.name)
    end

    it "logs updated site customizations" do
      old_json = ThemeSerializer.new(theme, root:false).to_json

      theme.set_field(:common, :scss, "body{margin: 10px;}")

      log_record = logger.log_theme_change(old_json, theme)

      expect(log_record.previous_value).to be_present

      json = ::JSON.parse(log_record.new_value)
      expect(json['theme_fields']).to eq([{"name" => "scss", "target" => "common", "value" => "body{margin: 10px;}"}])
    end
  end

  describe "log_theme_destroy" do
    it "raises an error when params are invalid" do
      expect { logger.log_theme_destroy(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      theme = Theme.new(name: 'Banana')
      theme.set_field(:common, :scss, "body{margin: 10px;}")

      log_record = logger.log_theme_destroy(theme)
      expect(log_record.previous_value).to be_present
      expect(log_record.new_value).to eq(nil)
      json = ::JSON.parse(log_record.previous_value)

      expect(json['theme_fields']).to eq([{"name" => "scss", "target" => "common", "value" => "body{margin: 10px;}"}])
    end
  end

  describe "log_site_text_change" do
    it "raises an error when params are invalid" do
      expect { logger.log_site_text_change(nil, 'new text', 'old text') }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      expect { logger.log_site_text_change('created', 'new text', 'old text') }.to change { UserHistory.count }.by(1)
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

  describe 'log_category_settings_change' do
    let(:category) { Fabricate(:category, name: 'haha') }
    let(:category_group) { Fabricate(:category_group, category: category, permission_type: 1) }

    it "raises an error when category is missing" do
      expect { logger.log_category_settings_change(nil, nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates new UserHistory records" do
      attributes = {
        name: 'new_name',
        permissions: { category_group.group_name => 2 }
      }

      category.update!(attributes)

      logger.log_category_settings_change(category, attributes,
        { category_group.group_name => category_group.permission_type }
      )

      expect(UserHistory.count).to eq(2)

      permission_user_history = UserHistory.find_by_subject('permissions')
      expect(permission_user_history.category_id).to eq(category.id)
      expect(permission_user_history.previous_value).to eq({ category_group.group_name => 1 }.to_json)
      expect(permission_user_history.new_value).to eq({ category_group.group_name => 2 }.to_json)
      expect(permission_user_history.action).to eq(UserHistory.actions[:change_category_settings])
      expect(permission_user_history.context).to eq(category.url)

      name_user_history = UserHistory.find_by_subject('name')
      expect(name_user_history.category).to eq(category)
      expect(name_user_history.previous_value).to eq('haha')
      expect(name_user_history.new_value).to eq('new_name')
    end

    it "does not log permissions changes for category visible to everyone" do
      attributes = { name: 'new_name' }
      old_permission = category.permissions_params
      category.update!(attributes)

      logger.log_category_settings_change(category, attributes.merge({ permissions: { "everyone" => 1 } }), old_permission)

      expect(UserHistory.count).to eq(1)
      expect(UserHistory.find_by_subject('name').category).to eq(category)
    end
  end

  describe 'log_category_deletion' do
    let(:parent_category) { Fabricate(:category) }
    let(:category) { Fabricate(:category, parent_category: parent_category) }

    it "raises an error when category is missing" do
      expect { logger.log_category_deletion(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      logger.log_category_deletion(category)

      expect(UserHistory.count).to eq(1)
      user_history = UserHistory.last

      expect(user_history.subject).to eq(nil)
      expect(user_history.category).to eq(category)
      expect(user_history.details).to include("parent_category: #{parent_category.name}")
      expect(user_history.context).to eq(category.url)
      expect(user_history.action).to eq(UserHistory.actions[:delete_category])
    end
  end

  describe 'log_category_creation' do
    let(:category) { Fabricate(:category) }

    it "raises an error when category is missing" do
      expect { logger.log_category_deletion(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      logger.log_category_creation(category)

      expect(UserHistory.count).to eq(1)
      user_history = UserHistory.last

      expect(user_history.category).to eq(category)
      expect(user_history.context).to eq(category.url)
      expect(user_history.action).to eq(UserHistory.actions[:create_category])
    end
  end

  describe 'log_lock_trust_level' do
    let(:user) { Fabricate(:user) }

    it "raises an error when argument is missing" do
      expect { logger.log_lock_trust_level(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      user.trust_level_locked = true
      expect { logger.log_lock_trust_level(user) }.to change { UserHistory.count }.by(1)
      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:lock_trust_level])

      user.trust_level_locked = false
      expect { logger.log_lock_trust_level(user) }.to change { UserHistory.count }.by(1)
      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:unlock_trust_level])
    end
  end

  describe 'log_user_activate' do
    let(:user) { Fabricate(:user) }

    it "raises an error when argument is missing" do
      expect { logger.log_user_activate(nil, nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      reason = "Staff activated from admin"
      expect {
        logger.log_user_activate(user, reason)
      }.to change { UserHistory.count }.by(1)
      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:activate_user])
      expect(user_history.details).to eq(reason)
    end
  end

  describe '#log_readonly_mode' do
    it "creates a new record" do
      expect { logger.log_change_readonly_mode(true) }.to change { UserHistory.count }.by(1)

      user_history = UserHistory.last

      expect(user_history.action).to eq(UserHistory.actions[:change_readonly_mode])
      expect(user_history.new_value).to eq('t')
      expect(user_history.previous_value).to eq('f')

      expect { logger.log_change_readonly_mode(false) }.to change { UserHistory.count }.by(1)

      user_history = UserHistory.last

      expect(user_history.action).to eq(UserHistory.actions[:change_readonly_mode])
      expect(user_history.new_value).to eq('f')
      expect(user_history.previous_value).to eq('t')
    end
  end
end
