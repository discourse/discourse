# frozen_string_literal: true

RSpec.describe StaffActionLogger do
  let(:long_string) { "Na " * 100_000 + "Batman!" }
  fab!(:admin)
  let(:logger) { described_class.new(admin) }

  describe "new" do
    it "raises an error when user is nil" do
      expect { described_class.new(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises an error when user is not a User" do
      expect { described_class.new(5) }.to raise_error(Discourse::InvalidParameters)
    end
  end

  describe "log_user_deletion" do
    subject(:log_user_deletion) { described_class.new(admin).log_user_deletion(deleted_user) }

    fab!(:deleted_user, :user)

    it "raises an error when user is nil" do
      expect { logger.log_user_deletion(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises an error when user is not a User" do
      expect { logger.log_user_deletion(1) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
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

  describe "log_post_deletion" do
    subject(:log_post_deletion) { described_class.new(admin).log_post_deletion(deleted_post) }

    fab!(:deleted_post, :post)

    it "raises an error when post is nil" do
      expect { logger.log_post_deletion(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises an error when post is not a Post" do
      expect { logger.log_post_deletion(1) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      expect { log_post_deletion }.to change { UserHistory.count }.by(1)
    end

    it "does not explode if post does not have a user" do
      expect {
        deleted_post.update_columns(user_id: nil)
        log_post_deletion
      }.to change { UserHistory.count }.by(1)
    end

    it "truncates overly long values" do
      deleted_post.update!(raw: long_string, skip_validation: true)
      expect { log_post_deletion }.to change { UserHistory.count }.by(1)
      log = UserHistory.last
      expect(log.details.size).to be_between(50_000, 110_000)
    end
  end

  describe "log_topic_delete_recover" do
    fab!(:topic)

    context "when deleting topic" do
      subject(:log_topic_delete_recover) do
        described_class.new(admin).log_topic_delete_recover(topic)
      end

      it "raises an error when topic is nil" do
        expect { logger.log_topic_delete_recover(nil) }.to raise_error(Discourse::InvalidParameters)
      end

      it "raises an error when topic is not a Topic" do
        expect { logger.log_topic_delete_recover(1) }.to raise_error(Discourse::InvalidParameters)
      end

      it "creates a new UserHistory record" do
        expect { log_topic_delete_recover }.to change { UserHistory.count }.by(1)
      end

      it "truncates overly long values" do
        Fabricate(:post, topic: topic, skip_validation: true, raw: long_string)
        expect { log_topic_delete_recover }.to change { UserHistory.count }.by(1)
        log = UserHistory.last
        expect(log.details.size).to be_between(50_000, 110_000)
      end
    end

    context "when recovering topic" do
      subject(:log_topic_delete_recover) do
        described_class.new(admin).log_topic_delete_recover(topic, "recover_topic")
      end

      it "raises an error when topic is nil" do
        expect { logger.log_topic_delete_recover(nil, "recover_topic") }.to raise_error(
          Discourse::InvalidParameters,
        )
      end

      it "raises an error when topic is not a Topic" do
        expect { logger.log_topic_delete_recover(1, "recover_topic") }.to raise_error(
          Discourse::InvalidParameters,
        )
      end

      it "creates a new UserHistory record" do
        expect { log_topic_delete_recover }.to change { UserHistory.count }.by(1)
      end

      it "truncates overly long values" do
        Fabricate(:post, topic: topic, skip_validation: true, raw: long_string)
        expect { log_topic_delete_recover }.to change { UserHistory.count }.by(1)
        log = UserHistory.last
        expect(log.details.size).to be_between(50_000, 110_000)
      end
    end
  end

  describe "log_trust_level_change" do
    subject(:log_trust_level_change) do
      described_class.new(admin).log_trust_level_change(user, old_trust_level, new_trust_level)
    end

    fab!(:user)

    let(:old_trust_level) { TrustLevel[0] }
    let(:new_trust_level) { TrustLevel[1] }

    it "raises an error when user or trust level is nil" do
      expect {
        logger.log_trust_level_change(nil, old_trust_level, new_trust_level)
      }.to raise_error(Discourse::InvalidParameters)
      expect { logger.log_trust_level_change(user, nil, new_trust_level) }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect { logger.log_trust_level_change(user, old_trust_level, nil) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    it "raises an error when user is not a User" do
      expect { logger.log_trust_level_change(1, old_trust_level, new_trust_level) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    it "raises an error when new trust level is not a Trust Level" do
      max_level = TrustLevel.valid_range.max
      expect { logger.log_trust_level_change(user, old_trust_level, max_level + 1) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    it "creates a new UserHistory record" do
      expect { log_trust_level_change }.to change { UserHistory.count }.by(1)
      expect(UserHistory.last.previous_value).to eq(old_trust_level.to_s)
      expect(UserHistory.last.new_value).to eq(new_trust_level.to_s)
    end
  end

  describe "log_site_setting_change" do
    it "raises an error when params are invalid" do
      expect { logger.log_site_setting_change(nil, "1", "2") }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect {
        logger.log_site_setting_change("i_am_a_site_setting_that_will_never_exist", "1", "2")
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      expect { logger.log_site_setting_change("title", "Discourse", "My Site") }.to change {
        UserHistory.count
      }.by(1)
    end

    it "logs boolean values" do
      log_record = logger.log_site_setting_change("allow_user_locale", true, false)
      expect(log_record.previous_value).to eq("true")
      expect(log_record.new_value).to eq("false")
    end

    it "logs nil values" do
      log_record = logger.log_site_setting_change("title", nil, nil)
      expect(log_record.previous_value).to be_nil
      expect(log_record.new_value).to be_nil
    end
  end

  # allow_user_locale is just used as an example here because upcoming
  # changes will not exist forever, so there aren't any stable names we
  # can use
  describe "log_upcoming_change_toggle" do
    it "raises an error when params are invalid" do
      expect { logger.log_upcoming_change_toggle(nil, false, true) }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect {
        logger.log_upcoming_change_toggle("change_that_will_not_exist", false, true)
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      expect { logger.log_upcoming_change_toggle("allow_user_locale", false, true) }.to change {
        UserHistory.count
      }.by(1)
    end

    it "records the details of why the toggle happened" do
      details =
        "This upcoming change was automatically enabled because it reached the 'Beta' status, which meets or exceeds the defined promotion status of 'Beta' on your site. See <a href='#{Discourse.base_url}/admin/config/upcoming-changes'>the upcoming changes page for details</a>."
      result = logger.log_upcoming_change_toggle("allow_user_locale", false, true, { details: })
      expect(result.details).to eq(details)
    end
  end

  describe "log_theme_change" do
    fab!(:theme)

    it "raises an error when params are invalid" do
      expect { logger.log_theme_change(nil, nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "logs new site customizations" do
      log_record = logger.log_theme_change(nil, theme)
      expect(log_record.subject).to eq(theme.name)
      expect(log_record.previous_value).to eq(nil)
      expect(log_record.new_value).to be_present

      json = ::JSON.parse(log_record.new_value)
      expect(json["name"]).to eq(theme.name)
    end

    it "logs updated site customizations" do
      old_json = ThemeSerializer.new(theme, root: false).to_json

      theme.set_field(target: :common, name: :scss, value: "body{margin: 10px;}")

      log_record = logger.log_theme_change(old_json, theme)

      expect(log_record.previous_value).to be_present

      json = ::JSON.parse(log_record.new_value)
      expect(json["theme_fields"]).to eq(
        [
          {
            "file_path" => "common/common.scss",
            "name" => "scss",
            "target" => "common",
            "value" => "body{margin: 10px;}",
            "type_id" => 1,
          },
        ],
      )
    end

    it "doesn't log values when the json is too large" do
      old_json = ThemeSerializer.new(theme, root: false).to_json

      theme.set_field(target: :common, name: :scss, value: long_string)

      log_record = logger.log_theme_change(old_json, theme)

      expect(log_record.previous_value).not_to be_present
      expect(log_record.new_value).not_to be_present
      expect(log_record.context).to be_present
    end
  end

  describe "log_theme_destroy" do
    fab!(:theme)

    it "raises an error when params are invalid" do
      expect { logger.log_theme_destroy(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      theme.set_field(target: :common, name: :scss, value: "body{margin: 10px;}")

      log_record = logger.log_theme_destroy(theme)
      expect(log_record.previous_value).to be_present
      expect(log_record.new_value).to eq(nil)
      json = ::JSON.parse(log_record.previous_value)

      expect(json["theme_fields"]).to eq(
        [
          {
            "file_path" => "common/common.scss",
            "name" => "scss",
            "target" => "common",
            "value" => "body{margin: 10px;}",
            "type_id" => 1,
          },
        ],
      )
    end

    it "doesn't log values when the json is too large" do
      theme.set_field(target: :common, name: :scss, value: long_string)
      log_record = logger.log_theme_destroy(theme)

      expect(log_record.previous_value).not_to be_present
      expect(log_record.new_value).not_to be_present
      expect(log_record.context).to be_present
    end
  end

  describe "log_theme_setting_change" do
    it "raises an error when params are invalid" do
      expect { logger.log_theme_setting_change(nil, nil, nil, nil) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    let! :theme do
      Fabricate(:theme)
    end

    before do
      theme.set_field(target: :settings, name: :yaml, value: "custom_setting: special")
      theme.save!
    end

    it "raises an error when theme setting is invalid" do
      expect {
        logger.log_theme_setting_change(:inexistent_setting, nil, nil, theme)
      }.to raise_error(Discourse::InvalidParameters)
    end

    it "logs theme setting changes" do
      log_record =
        logger.log_theme_setting_change(:custom_setting, "special", "notsospecial", theme)
      expect(log_record.subject).to eq("#{theme.name}: custom_setting")
      expect(log_record.previous_value).to eq("special")
      expect(log_record.new_value).to eq("notsospecial")
    end
  end

  describe "log_site_text_change" do
    it "raises an error when params are invalid" do
      expect { logger.log_site_text_change(nil, "new text", "old text") }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    it "creates a new UserHistory record" do
      expect { logger.log_site_text_change("created", "new text", "old text") }.to change {
        UserHistory.count
      }.by(1)
    end
  end

  describe "log_user_suspend" do
    fab!(:user) { Fabricate(:user, suspended_at: 10.minutes.ago, suspended_till: 1.day.from_now) }

    it "raises an error when arguments are missing" do
      expect { logger.log_user_suspend(nil, nil) }.to raise_error(Discourse::InvalidParameters)
      expect { logger.log_user_suspend(nil, "He was bad.") }.to raise_error(
        Discourse::InvalidParameters,
      )
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
    fab!(:user) { Fabricate(:user, suspended_at: 1.day.ago, suspended_till: 7.days.from_now) }

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
    fab!(:user)
    fab!(:badge)
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

  describe "log_roll_up" do
    subject(:log_roll_up) { described_class.new(admin).log_roll_up(subnet, ips) }

    let(:subnet) { "1.2.3.0/24" }
    let(:ips) { %w[1.2.3.4 1.2.3.100] }

    it "creates a new UserHistory record" do
      log_record = logger.log_roll_up(subnet, ips)
      expect(log_record).to be_valid
      expect(log_record.details).to eq("#{subnet} from #{ips.join(", ")}")
    end
  end

  describe "log_custom" do
    it "raises an error when `custom_type` is missing" do
      expect { logger.log_custom(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates the UserHistory record" do
      logged =
        logger.log_custom("clicked_something", evil: "trout", clicked_on: "thing", topic_id: 1234)
      expect(logged).to be_valid
      expect(logged.details).to eq("evil: trout\nclicked_on: thing")
      expect(logged.action).to eq(UserHistory.actions[:custom_staff])
      expect(logged.custom_type).to eq("clicked_something")
      expect(logged.topic_id).to be === 1234
    end

    it "truncates overly long values" do
      logged = logger.log_custom(:shower_thought, lyrics: long_string)
      expect(logged).to be_valid
      expect(logged.details.size).to be_between(50_000, 110_000)
    end
  end

  describe "log_category_settings_change" do
    let(:category) { Fabricate(:category, name: "haha") }
    let(:category_group) { Fabricate(:category_group, category: category, permission_type: 1) }

    it "raises an error when category is missing" do
      expect { logger.log_category_settings_change(nil, nil) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    it "creates new UserHistory records" do
      attributes = { name: "new_name", permissions: { category_group.group_name => 2 } }

      category.update!(attributes)

      logger.log_category_settings_change(
        category,
        attributes,
        old_permissions: {
          category_group.group_name => category_group.permission_type,
        },
      )

      expect(UserHistory.count).to eq(2)

      permission_user_history = UserHistory.find_by_subject("permissions")
      expect(permission_user_history.category_id).to eq(category.id)
      expect(permission_user_history.previous_value).to eq(
        { category_group.group_name => 1 }.to_json,
      )
      expect(permission_user_history.new_value).to eq({ category_group.group_name => 2 }.to_json)
      expect(permission_user_history.action).to eq(UserHistory.actions[:change_category_settings])
      expect(permission_user_history.context).to eq(category.url)

      name_user_history = UserHistory.find_by_subject("name")
      expect(name_user_history.category).to eq(category)
      expect(name_user_history.previous_value).to eq("haha")
      expect(name_user_history.new_value).to eq("new_name")
    end

    it "logs permissions changes even if the category is visible to everyone" do
      attributes = { name: "new_name" }
      old_permission = { "everyone" => 1 }
      category.update!(attributes)

      logger.log_category_settings_change(
        category,
        attributes.merge(permissions: { "trust_level_3" => 1 }),
        old_permissions: old_permission,
      )

      expect(UserHistory.count).to eq(2)
      expect(UserHistory.find_by_subject("name").category).to eq(category)
    end

    it "logs custom fields changes" do
      attributes = { custom_fields: { "auto_populated" => "t" } }
      category.update!(attributes)

      logger.log_category_settings_change(
        category,
        attributes,
        old_permissions: category.permissions_params,
        old_custom_fields: {
        },
      )

      expect(UserHistory.count).to eq(1)
    end

    it "does not log custom fields changes if value is unchanged" do
      attributes = { custom_fields: { "auto_populated" => "t" } }
      category.update!(attributes)

      logger.log_category_settings_change(
        category,
        attributes,
        old_permissions: category.permissions_params,
        old_custom_fields: {
          "auto_populated" => "t",
        },
      )

      expect(UserHistory.count).to eq(0)
    end
  end

  describe "log_category_deletion" do
    fab!(:parent_category, :category)
    fab!(:category) { Fabricate(:category, parent_category: parent_category) }

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

  describe "log_category_creation" do
    fab!(:category)

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

  describe "log_lock_trust_level" do
    fab!(:user)

    it "raises an error when argument is missing" do
      expect { logger.log_lock_trust_level(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      user.manual_locked_trust_level = 3
      expect { logger.log_lock_trust_level(user) }.to change { UserHistory.count }.by(1)
      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:lock_trust_level])

      user.manual_locked_trust_level = nil
      expect { logger.log_lock_trust_level(user) }.to change { UserHistory.count }.by(1)
      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:unlock_trust_level])
    end
  end

  describe "log_user_activate" do
    fab!(:user)

    it "raises an error when argument is missing" do
      expect { logger.log_user_activate(nil, nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      reason = "Staff activated from admin"
      expect { logger.log_user_activate(user, reason) }.to change { UserHistory.count }.by(1)
      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:activate_user])
      expect(user_history.details).to eq(reason)
    end
  end

  describe "#log_readonly_mode" do
    it "creates a new record" do
      expect { logger.log_change_readonly_mode(true) }.to change { UserHistory.count }.by(1)

      user_history = UserHistory.last

      expect(user_history.action).to eq(UserHistory.actions[:change_readonly_mode])
      expect(user_history.new_value).to eq("t")
      expect(user_history.previous_value).to eq("f")

      expect { logger.log_change_readonly_mode(false) }.to change { UserHistory.count }.by(1)

      user_history = UserHistory.last

      expect(user_history.action).to eq(UserHistory.actions[:change_readonly_mode])
      expect(user_history.new_value).to eq("f")
      expect(user_history.previous_value).to eq("t")
    end
  end

  describe "log_check_personal_message" do
    subject(:log_check_personal_message) do
      described_class.new(admin).log_check_personal_message(personal_message)
    end

    fab!(:personal_message, :private_message_topic)

    it "raises an error when topic is nil" do
      expect { logger.log_check_personal_message(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises an error when topic is not a Topic" do
      expect { logger.log_check_personal_message(1) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      expect { log_check_personal_message }.to change { UserHistory.count }.by(1)
    end
  end

  describe "log_post_approved" do
    subject(:log_post_approved) { described_class.new(admin).log_post_approved(approved_post) }

    fab!(:approved_post, :post)

    it "raises an error when post is nil" do
      expect { logger.log_post_approved(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "raises an error when post is not a Post" do
      expect { logger.log_post_approved(1) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      expect { log_post_approved }.to change { UserHistory.count }.by(1)
    end
  end

  describe "log_post_rejected" do
    subject(:log_post_rejected) do
      described_class.new(admin).log_post_rejected(reviewable, DateTime.now)
    end

    fab!(:reviewable, :reviewable_queued_post)

    it "raises an error when reviewable not supplied" do
      expect { logger.log_post_rejected(nil, DateTime.now) }.to raise_error(
        Discourse::InvalidParameters,
      )
      expect { logger.log_post_rejected(1, DateTime.now) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    it "creates a new UserHistory record" do
      expect { log_post_rejected }.to change { UserHistory.count }.by(1)
      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:post_rejected])
      expect(user_history.details).to include(reviewable.payload["raw"])
    end

    it "works if the user was destroyed" do
      reviewable.created_by.destroy
      reviewable.reload

      expect { log_post_rejected }.to change { UserHistory.count }.by(1)
      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:post_rejected])
      expect(user_history.details).to include(reviewable.payload["raw"])
    end

    it "truncates overly long values" do
      reviewable.payload["raw"] = long_string
      reviewable.save!

      expect { log_post_rejected }.to change { UserHistory.count }.by(1)
      log = UserHistory.last
      expect(log.details.size).to be_between(50_000, 110_000)
    end
  end

  describe "log_topic_closed" do
    fab!(:topic)

    it "raises an error when argument is missing" do
      expect { logger.log_topic_closed(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      expect { logger.log_topic_closed(topic, closed: true) }.to change {
        UserHistory.where(action: UserHistory.actions[:topic_closed]).count
      }.by(1)
      expect { logger.log_topic_closed(topic, closed: false) }.to change {
        UserHistory.where(action: UserHistory.actions[:topic_opened]).count
      }.by(1)
    end
  end

  describe "log_topic_archived" do
    fab!(:topic)

    it "raises an error when argument is missing" do
      expect { logger.log_topic_archived(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      expect { logger.log_topic_archived(topic, archived: true) }.to change {
        UserHistory.where(action: UserHistory.actions[:topic_archived]).count
      }.by(1)
      expect { logger.log_topic_archived(topic, archived: false) }.to change {
        UserHistory.where(action: UserHistory.actions[:topic_unarchived]).count
      }.by(1)
    end
  end

  describe "log_post_staff_note" do
    fab!(:post)

    it "raises an error when argument is missing" do
      expect { logger.log_topic_archived(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      expect {
        logger.log_post_staff_note(post, { new_value: "my note", old_value: nil })
      }.to change { UserHistory.count }.by(1)
      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:post_staff_note_create])
      expect(user_history.new_value).to eq("my note")
      expect(user_history.previous_value).to eq(nil)

      expect {
        logger.log_post_staff_note(post, { new_value: nil, old_value: "my note" })
      }.to change { UserHistory.count }.by(1)
      user_history = UserHistory.last
      expect(user_history.action).to eq(UserHistory.actions[:post_staff_note_destroy])
      expect(user_history.new_value).to eq(nil)
      expect(user_history.previous_value).to eq("my note")
    end
  end

  describe "#log_watched_words_creation" do
    fab!(:watched_word) { Fabricate(:watched_word, action: WatchedWord.actions[:block]) }

    it "raises an error when watched_word is missing" do
      expect { logger.log_watched_words_creation(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      logger.log_watched_words_creation(watched_word)

      expect(UserHistory.count).to eq(1)
      user_history = UserHistory.last

      expect(user_history.subject).to eq(nil)
      expect(user_history.details).to include(watched_word.word)
      expect(user_history.context).to eq("block")
      expect(user_history.action).to eq(UserHistory.actions[:watched_word_create])
    end
  end

  describe "#log_watched_words_deletion" do
    fab!(:watched_word) { Fabricate(:watched_word, action: WatchedWord.actions[:block]) }

    it "raises an error when watched_word is missing" do
      expect { logger.log_watched_words_deletion(nil) }.to raise_error(Discourse::InvalidParameters)
    end

    it "creates a new UserHistory record" do
      logger.log_watched_words_deletion(watched_word)

      expect(UserHistory.count).to eq(1)
      user_history = UserHistory.last

      expect(user_history.subject).to eq(nil)
      expect(user_history.details).to include(watched_word.word)
      expect(user_history.context).to eq("block")
      expect(user_history.action).to eq(UserHistory.actions[:watched_word_destroy])
    end
  end
end
