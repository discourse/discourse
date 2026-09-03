# frozen_string_literal: true

# One-time suite bootstrap: disable expensive subsystems, check for pending
# migrations, (on CI) widen INT foreign-key columns to BIGINT, quiet noisy
# output, wire the test current-user provider, and reset themes.
RSpec.configure do |config|
  config.before(:suite) do
    CachedCounting.disable

    begin
      ActiveRecord::Migration.check_all_pending!
    rescue ActiveRecord::PendingMigrationError
      raise "There are pending migrations, run RAILS_ENV=test bin/rake db:migrate"
    end

    # On CI, widen the INT columns referenced by BIGINT foreign keys and bump
    # their sequences past the INT max so the types line up.
    if ENV["CI"].present?
      [
        [PostAction, :post_action_type_id],
        [Reviewable, :target_id],
        [ReviewableHistory, :reviewable_id],
        [ReviewableScore, :reviewable_id],
        [ReviewableScore, :reviewable_score_type],
        [SidebarSectionLink, :linkable_id],
        [SidebarSectionLink, :sidebar_section_id],
        [User, :last_seen_reviewable_id],
        [User, :required_fields_version],
      ].each do |model, column|
        DB.exec("ALTER TABLE #{model.table_name} ALTER #{column} TYPE bigint")
        model.reset_column_information
      end

      # Sets sequence's value to be greater than the max value that an INT column can hold. This is done to prevent
      # type mismatches for foreign keys that references a column of type BIGINT. We set the value to 10_000_000_000
      # instead of 2**31-1 so that the values are easier to read.
      DB
        .query("SELECT sequence_name FROM information_schema.sequences WHERE data_type = 'bigint'")
        .each do |row|
          DB.exec "SELECT setval('#{row.sequence_name}', GREATEST((SELECT last_value FROM #{row.sequence_name}), 10000000000))"
        end
    end

    Sidekiq.default_configuration.error_handlers.clear

    # No-op handler to suppress Sidekiq's `p ["!!!!!", ex]` fallback.
    Sidekiq.default_configuration.error_handlers << ->(_ex, _ctx, _config) {}

    # Quiet seed-fu output produced by specs that call `Model.seed`.
    SeedFu.quiet = true

    # json-schema's MultiJSON support is deprecated.
    JSON::Validator.use_multi_json = false

    # Ugly, but needed until we have a user creator
    User.skip_callback(:create, :after, :ensure_in_trust_level_group)

    DiscoursePluginRegistry.reset! if ENV["LOAD_PLUGINS"] != "1"
    Discourse.current_user_provider = TestCurrentUserProvider
    Discourse::Application.load_tasks

    SystemThemesManager.clear_system_theme_user_history!
    ThemeField.delete_all
    ThemeSettingsMigration.delete_all
    JavascriptCache.delete_all
    ThemeSiteSetting.delete_all
    SiteSetting.refresh!
  end
end
