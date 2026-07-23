# frozen_string_literal: true

# Per-test global-state reset, run before every example and every before_all
# block. `before_next_spec` queues one-shot cleanups that TestSetup drains here.

module TestSetup
  # This is run before each test and before each before_all block
  def self.test_setup(x = nil)
    # This allows DB.transaction_open? to work in tests. See lib/mini_sql_multisite_connection.rb
    DB.test_transaction = ActiveRecord::Base.connection.current_transaction

    RateLimiter.disable
    PostActionNotifier.disable
    SearchIndexer.disable
    UserActionManager.disable
    NotificationEmailer.disable
    SiteIconManager.disable
    WordWatcher.disable_cache
    UpcomingChanges.clear_caches!

    SiteSetting.provider.clear
    SiteSetting.refresh!(refresh_theme_site_settings: false)

    # Set some standard overrides for tests. Some for performance, some to make the tests easier,
    # and some because their default was changed, and we didn't want to refactor all the relevant specs.
    {
      s3_upload_bucket: "bucket",
      min_post_length: 5,
      min_first_post_length: 5,
      min_personal_message_post_length: 10,
      download_remote_images_to_local: false,
      unique_posts_mins: 0,
      max_consecutive_replies: 0,
      allow_uncategorized_topics: true,
    }.each { |k, v| SiteSetting.set(k, v) }

    SiteSetting.refresh!(refresh_site_settings: false, refresh_theme_site_settings: true)
    SiteSetting.refresh_site_setting_group_ids!

    # very expensive IO operations
    SiteSetting.automatically_download_gravatars = false

    Discourse.clear_readonly!
    Sidekiq::Worker.clear_all

    I18n.locale = SiteSettings::DefaultsProvider::DEFAULT_LOCALE

    # Database is rolled back between specs, but I18n override cache doesn't.
    # Flush it if there were any TranslationOverrides created.
    overrides_by_site = I18n.instance_variable_get(:@overrides_by_site) || {}
    if overrides_by_site.values.flat_map(&:values).any?(&:any?)
      I18n.reload!
      ExtraLocalesController.clear_cache!
    end

    RspecErrorTracker.clear_exceptions

    if $test_cleanup_callbacks
      $test_cleanup_callbacks.reverse_each(&:call)
      $test_cleanup_callbacks = nil
    end

    # in test this is very expensive, we explicitly enable when needed
    Topic.update_featured_topics = false

    # Running jobs are expensive and most of our tests are not concern with
    # code that runs inside jobs. run_later! means they are put on the redis
    # queue and never processed.
    Jobs.run_later!

    # Don't track ApplicationRequests in test mode unless opted in
    ApplicationRequest.disable

    # Don't queue badge grant in test mode
    BadgeGranter.disable_queue

    OmniAuth.config.test_mode = false

    Middleware::AnonymousCache.disable_anon_cache
    BlockRequestsMiddleware.allow_requests!
    BlockRequestsMiddleware.current_example_location = nil
    ApplicationSerializer.fragment_cache.clear
  end
end

def before_next_spec(&callback)
  ($test_cleanup_callbacks ||= []) << callback
end
