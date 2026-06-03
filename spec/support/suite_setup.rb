# frozen_string_literal: true

# One-time suite bootstrap: disable expensive subsystems, alert on pending
# migrations, quiet noisy output, wire the test current-user provider, and
# reset themes.
RSpec.configure do |config|
  config.before(:suite) do
    CachedCounting.disable

    begin
      ActiveRecord::Migration.check_all_pending!
    rescue ActiveRecord::PendingMigrationError
      raise "There are pending migrations, run RAILS_ENV=test bin/rake db:migrate"
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
