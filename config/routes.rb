# frozen_string_literal: true

require "sidekiq/web"
require "mini_scheduler/web"

# The following constants have been replaced with `RouteFormat` and are deprecated.
USERNAME_ROUTE_FORMAT = /[%\w.\-]+?/ unless defined?(USERNAME_ROUTE_FORMAT)
BACKUP_ROUTE_FORMAT = /.+\.(sql\.gz|tar\.gz|tgz)/i unless defined?(BACKUP_ROUTE_FORMAT)

Discourse::Application.routes.draw do
  def patch(*)
  end # Disable PATCH requests

  scope path: nil, constraints: { format: %r{(json|html|\*/\*)} } do
    relative_url_root =
      (
        if (
             defined?(Rails.configuration.relative_url_root) &&
               Rails.configuration.relative_url_root
           )
          Rails.configuration.relative_url_root + "/"
        else
          "/"
        end
      )

    match "/404", to: "exceptions#not_found", via: %i[get post]
    get "/404-body" => "exceptions#not_found_body"

    if Rails.env.test? || Rails.env.development?
      get "/bootstrap/plugin-css-for-tests.css" => "bootstrap#plugin_css_for_tests"
    end

    # This is not a valid production route and is causing routing errors to be raised in
    # the test env adding noise to the logs. Just handle it here so we eliminate the noise.
    get "/favicon.ico", to: proc { [200, {}, [""]] } if Rails.env.test?

    post "webhooks/aws" => "webhooks#aws"
    post "webhooks/mailgun" => "webhooks#mailgun"
    post "webhooks/mailjet" => "webhooks#mailjet"
    post "webhooks/mailpace" => "webhooks#mailpace"
    post "webhooks/mandrill" => "webhooks#mandrill"
    get "webhooks/mandrill" => "webhooks#mandrill_head"
    post "webhooks/postmark" => "webhooks#postmark"
    post "webhooks/sendgrid" => "webhooks#sendgrid"
    post "webhooks/sparkpost" => "webhooks#sparkpost"

    scope path: nil, format: true, constraints: { format: :xml } do
      resources :sitemap, only: [:index]
      get "/sitemap_:page" => "sitemap#page", :page => /[1-9][0-9]*/
      get "/sitemap_recent" => "sitemap#recent"
      get "/news" => "sitemap#news"
    end

    scope path: nil, constraints: { format: /.*/ } do
      if Rails.env.development?
        mount Sidekiq::Web => "/sidekiq"
        mount Logster::Web => "/logs"
      else
        # only allow sidekiq in master site
        mount Sidekiq::Web => "/sidekiq", :constraints => AdminConstraint.new(require_master: true)
        mount Logster::Web => "/logs", :constraints => AdminConstraint.new
      end
    end

    resources :about, only: [:index] do
      collection { get "live_post_counts" }
    end

    get "finish-installation" => "finish_installation#index"
    get "finish-installation/register" => "finish_installation#register"
    post "finish-installation/register" => "finish_installation#register"
    get "finish-installation/confirm-email" => "finish_installation#confirm_email"
    put "finish-installation/resend-email" => "finish_installation#resend_email"

    get "pub/check-slug" => "published_pages#check_slug"
    get "pub/by-topic/:topic_id" => "published_pages#details"
    put "pub/by-topic/:topic_id" => "published_pages#upsert"
    delete "pub/by-topic/:topic_id" => "published_pages#destroy"
    get "pub/:slug" => "published_pages#show"

    resources :directory_items, only: [:index]

    get "site" => "site#site"
    namespace :site do
      get "settings"
      get "custom_html"
      get "banner"
      get "emoji"
    end

    get "site/basic-info" => "site#basic_info"
    get "site/statistics" => "site#statistics"

    get "srv/status" => "forums#status"

    get "wizard" => "wizard#index"
    get "wizard/steps/:id" => "wizard#index"
    put "wizard/steps/:id" => "steps#update"

    namespace :admin, constraints: StaffConstraint.new do
      get "" => "admin#index"

      get "plugins" => "plugins#index"
      get "plugins/:plugin_id" => "plugins#show"
      get "plugins/:plugin_id/settings" => "plugins#show"

      resources :site_settings, only: %i[index update], constraints: AdminConstraint.new do
        collection { get "category/:id" => "site_settings#index" }

        put "user_count" => "site_settings#user_count"
      end

      get "reports" => "reports#index"
      get "reports/bulk" => "reports#bulk"
      get "reports/:type" => "reports#show"

      resources :groups, only: [:create] do
        member do
          delete "owners" => "groups#remove_owner"
          put "primary" => "groups#set_primary"
        end
      end
      resources :groups, only: [:destroy], constraints: AdminConstraint.new do
        collection { put "automatic_membership_count" => "groups#automatic_membership_count" }
      end

      resources :users, id: RouteFormat.username, only: %i[index destroy] do
        collection do
          get "list" => "users#index"
          get "list/:query" => "users#index"
          get "ip-info" => "users#ip_info"
          delete "delete-others-with-same-ip" => "users#delete_other_accounts_with_same_ip"
          get "total-others-with-same-ip" => "users#total_other_accounts_with_same_ip"
          put "approve-bulk" => "users#approve_bulk"
          delete "destroy-bulk" => "users#destroy_bulk"
        end
        delete "penalty_history", constraints: AdminConstraint.new
        put "suspend"
        put "delete_posts_batch"
        put "unsuspend"
        put "revoke_admin", constraints: AdminConstraint.new
        put "grant_admin", constraints: AdminConstraint.new
        put "revoke_moderation", constraints: AdminConstraint.new
        put "grant_moderation", constraints: AdminConstraint.new
        put "approve"
        post "log_out", constraints: AdminConstraint.new
        put "activate"
        put "deactivate"
        put "silence"
        put "unsilence"
        put "trust_level"
        put "trust_level_lock"
        put "primary_group"
        post "groups" => "users#add_group", :constraints => AdminConstraint.new
        delete "groups/:group_id" => "users#remove_group", :constraints => AdminConstraint.new
        get "badges"
        get "leader_requirements" => "users#tl3_requirements"
        get "tl3_requirements"
        put "anonymize"
        post "merge"
        post "reset-bounce-score"
        put "disable_second_factor"
        delete "sso_record"
        get "similar-users.json" => "users#similar_users"
        put "delete_associated_accounts"
      end
      get "users/:id.json" => "users#show", :defaults => { format: "json" }
      get "users/:id/:username" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          },
          :as => :user_show
      get "users/:id/:username/badges" => "users#show"
      get "users/:id/:username/tl3_requirements" => "users#show"

      post "users/sync_sso" => "users#sync_sso", :constraints => AdminConstraint.new

      resources :impersonate, only: %i[index create], constraints: AdminConstraint.new

      resources :email, only: [:index], constraints: AdminConstraint.new do
        collection do
          post "test"
          get "sent"
          get "skipped"
          get "bounced"
          get "received"
          get "rejected"
          get "/incoming/:id" => "email#incoming"
          get "/incoming_from_bounced/:id" => "email#incoming_from_bounced"
          get "preview-digest" => "email#preview_digest"
          post "send-digest" => "email#send_digest"
          get "smtp_should_reject"
          post "handle_mail"
          get "advanced-test"
          post "advanced-test" => "email#advanced_test"
        end
      end

      scope "/logs" do
        resources :staff_action_logs, only: [:index]
        get "staff_action_logs/:id/diff" => "staff_action_logs#diff"
        resources :screened_emails, only: %i[index destroy]
        resources :screened_ip_addresses, only: %i[index create update destroy]
        resources :screened_urls, only: [:index]
        resources :search_logs, only: [:index]
        get "search_logs/term/" => "search_logs#term"
      end

      get "/logs" => "staff_action_logs#index"

      # alias
      get "/logs/watched_words", to: redirect(relative_url_root + "admin/customize/watched_words")
      get "/logs/watched_words/*path",
          to: redirect(relative_url_root + "admin/customize/watched_words/%{path}")

      get "customize" => "color_schemes#index", :constraints => AdminConstraint.new
      get "customize/themes" => "themes#index", :constraints => AdminConstraint.new
      get "customize/components" => "themes#index", :constraints => AdminConstraint.new
      get "customize/theme-components" => "themes#index", :constraints => AdminConstraint.new
      get "customize/colors" => "color_schemes#index", :constraints => AdminConstraint.new
      get "customize/colors/:id" => "color_schemes#index", :constraints => AdminConstraint.new
      get "config/permalinks" => "permalinks#index", :constraints => AdminConstraint.new
      get "customize/embedding" => "embedding#show", :constraints => AdminConstraint.new
      put "customize/embedding" => "embedding#update", :constraints => AdminConstraint.new
      get "customize/embedding/:id" => "embedding#edit", :constraints => AdminConstraint.new

      resources :themes,
                only: %i[index create show update destroy],
                constraints: AdminConstraint.new do
        member do
          get "preview" => "themes#preview"
          get "translations/:locale" => "themes#get_translations"
          put "setting" => "themes#update_single_setting"
          get "objects_setting_metadata/:setting_name" => "themes#objects_setting_metadata"
        end

        collection do
          post "import" => "themes#import"
          post "upload_asset" => "themes#upload_asset"
          post "generate_key_pair" => "themes#generate_key_pair"
          delete "bulk_destroy" => "themes#bulk_destroy"
        end
      end

      scope "/customize", constraints: AdminConstraint.new do
        resources :form_templates, constraints: AdminConstraint.new, path: "/form-templates" do
          collection { get "preview" => "form_templates#preview" }
        end

        get "themes/:id/:target/:field_name/edit" => "themes#index"
        get "themes/:id" => "themes#index"
        get "components/:id" => "themes#index"
        get "components/:id/:target/:field_name/edit" => "themes#index"
        get "themes/:id/export" => "themes#export"
        get "themes/:id/schema/:setting_name" => "themes#schema"
        get "components/:id/schema/:setting_name" => "themes#schema"

        # They have periods in their URLs often:
        get "site_texts" => "site_texts#index"
        get "site_texts/:id.json" => "site_texts#show", :constraints => { id: /[\w.\-\+\%\&]+/i }
        get "site_texts/:id" => "site_texts#show", :constraints => { id: /[\w.\-\+\%\&]+/i }
        put "site_texts/:id.json" => "site_texts#update", :constraints => { id: /[\w.\-\+\%\&]+/i }
        put "site_texts/:id" => "site_texts#update", :constraints => { id: /[\w.\-\+\%\&]+/i }
        delete "site_texts/:id.json" => "site_texts#revert",
               :constraints => {
                 id: /[\w.\-\+\%\&]+/i,
               }
        delete "site_texts/:id" => "site_texts#revert", :constraints => { id: /[\w.\-\+\%\&]+/i }
        put "site_texts/:id/dismiss_outdated" => "site_texts#dismiss_outdated",
            :constraints => {
              id: /[\w.\-\+\%\&]+/i,
            }
        put "site_texts/:id/dismiss_outdated.json" => "site_texts#dismiss_outdated",
            :constraints => {
              id: /[\w.\-\+\%\&]+/i,
            }

        get "reseed" => "site_texts#get_reseed_options"
        post "reseed" => "site_texts#reseed"

        get "email_templates" => "email_templates#index"
        get "email_templates/(:id)" => "email_templates#show", :constraints => { id: /[0-9a-z_.]+/ }
        put "email_templates/(:id)" => "email_templates#update",
            :constraints => {
              id: /[0-9a-z_.]+/,
            }
        delete "email_templates/(:id)" => "email_templates#revert",
               :constraints => {
                 id: /[0-9a-z_.]+/,
               }

        get "robots" => "robots_txt#show"
        put "robots.json" => "robots_txt#update"
        delete "robots.json" => "robots_txt#reset"

        resource :email_style, only: %i[show update]
        get "email_style/:field" => "email_styles#show", :constraints => { field: /html|css/ }
      end

      resources :embeddable_hosts, only: %i[create update destroy], constraints: AdminConstraint.new
      resources :color_schemes,
                only: %i[index create update destroy],
                constraints: AdminConstraint.new
      resources :permalinks,
                only: %i[index create show update destroy],
                constraints: AdminConstraint.new

      scope "/customize" do
        resources :watched_words, only: %i[index create destroy] do
          collection do
            get "action/:id" => "watched_words#index"
            get "action/:id/download" => "watched_words#download"
            delete "action/:id" => "watched_words#clear_all"
          end
        end
        post "watched_words/upload" => "watched_words#upload"
      end

      get "version_check" => "versions#show"

      get "dashboard" => "dashboard#index"
      get "dashboard/general" => "dashboard#general"
      get "dashboard/moderation" => "dashboard#moderation"
      get "dashboard/security" => "dashboard#security"
      get "dashboard/reports" => "dashboard#reports"
      get "dashboard/whats-new" => "dashboard#new_features"
      get "/whats-new" => "dashboard#new_features"
      post "/toggle-feature" => "dashboard#toggle_feature"

      resources :dashboard, only: [:index] do
        collection { get "problems" }
      end

      resources :api, only: [:index], constraints: AdminConstraint.new do
        collection do
          resources :keys, controller: "api", only: %i[index show update create destroy] do
            collection { get "scopes" => "api#scopes" }

            member do
              post "revoke" => "api#revoke_key"
              post "undo-revoke" => "api#undo_revoke_key"
            end
          end

          resources :web_hooks, only: %i[index create show edit update destroy]
          get "web_hook_events/:id" => "web_hooks#list_events", :as => :web_hook_events
          get "web_hooks/:id/events/bulk" => "web_hooks#bulk_events"
          post "web_hooks/:web_hook_id/events/:event_id/redeliver" => "web_hooks#redeliver_event"
          post "web_hooks/:id/events/failed_redeliver" => "web_hooks#redeliver_failed_events"
          post "web_hooks/:id/ping" => "web_hooks#ping"
        end
      end

      resources :backups, only: %i[index create], constraints: AdminConstraint.new do
        member do
          get "" => "backups#show", :constraints => { id: RouteFormat.backup }
          put "" => "backups#email", :constraints => { id: RouteFormat.backup }
          delete "" => "backups#destroy", :constraints => { id: RouteFormat.backup }
          post "restore" => "backups#restore", :constraints => { id: RouteFormat.backup }
        end
        collection do
          # multipart uploads
          post "create-multipart" => "backups#create_multipart", :format => :json
          post "complete-multipart" => "backups#complete_multipart", :format => :json
          post "abort-multipart" => "backups#abort_multipart", :format => :json
          post "batch-presign-multipart-parts" => "backups#batch_presign_multipart_parts",
               :format => :json

          get "logs" => "backups#logs"
          get "settings" => "backups#index"
          get "status" => "backups#status"
          delete "cancel" => "backups#cancel"
          post "rollback" => "backups#rollback"
          put "readonly" => "backups#readonly"
          get "upload" => "backups#check_backup_chunk"
          post "upload" => "backups#upload_backup_chunk"
          get "upload_url" => "backups#create_upload_url"
        end
      end

      resources :badges,
                only: %i[index new show create update destroy],
                constraints: AdminConstraint.new do
        collection do
          get "/award/:badge_id" => "badges#award"
          post "/award/:badge_id" => "badges#mass_award"
          get "types" => "badges#badge_types"
          post "badge_groupings" => "badges#save_badge_groupings"
          post "preview" => "badges#preview"
        end
      end
      namespace :config, constraints: StaffConstraint.new do
        resources :site_settings, only: %i[index]

        get "fonts" => "site_settings#index"
        get "login-and-authentication" => "site_settings#index"
        get "logo" => "site_settings#index"
        get "notifications" => "site_settings#index"
        get "trust-levels" => "site_settings#index"

        resources :flags, only: %i[index new create update destroy] do
          put "toggle"
          put "reorder/:direction" => "flags#reorder"
          member { get "/" => "flags#edit" }
        end

        resources :about, constraints: AdminConstraint.new, only: %i[index] do
          collection { put "/" => "about#update" }
        end

        resources :look_and_feel,
                  path: "look-and-feel",
                  constraints: AdminConstraint.new,
                  only: %i[index] do
          collection { get "/themes" => "look_and_feel#themes" }
        end
      end

      scope "/config" do
        resources :user_fields,
                  path: "user_fields",
                  only: %i[index create update destroy],
                  constraints: AdminConstraint.new
        get "user-fields/new" => "user_fields#index"
        get "user-fields/:id" => "user_fields#show"
        get "user-fields/:id/edit" => "user_fields#edit"
        get "user-fields" => "user_fields#index"

        get "user_fields/new" => "user_fields#index"
        get "user_fields/:id" => "user_fields#show"
        get "user_fields/:id/edit" => "user_fields#edit"

        resources :emoji, only: %i[index create destroy], constraints: AdminConstraint.new
        get "emoji/new" => "emoji#index"
        get "emoji/settings" => "emoji#index"
        resources :permalinks, only: %i[index new create show destroy]
      end

      get "section/:section_id" => "section#show", :constraints => AdminConstraint.new
      resources :admin_notices, only: %i[destroy], constraints: AdminConstraint.new
    end # admin namespace

    get "email/unsubscribe/:key" => "email#unsubscribe", :as => "email_unsubscribe"
    get "email/unsubscribed" => "email#unsubscribed", :as => "email_unsubscribed"
    post "email/unsubscribe/:key" => "email#perform_unsubscribe", :as => "email_perform_unsubscribe"

    get "extra-locales/:bundle" => "extra_locales#show"

    resources :session, id: RouteFormat.username, only: %i[create destroy become] do
      get "become" if !Rails.env.production?

      collection { post "forgot_password" }
    end

    get "review" => "reviewables#index" # For ember app
    get "review/:reviewable_id" => "reviewables#show", :constraints => { reviewable_id: /\d+/ }
    get "review/:reviewable_id/explain" => "reviewables#explain",
        :constraints => {
          reviewable_id: /\d+/,
        }
    get "review/count" => "reviewables#count"
    get "review/topics" => "reviewables#topics"
    get "review/settings" => "reviewables#settings"
    get "review/user-menu-list" => "reviewables#user_menu_list", :format => :json
    put "review/settings" => "reviewables#settings"
    put "review/:reviewable_id/perform/:action_id" => "reviewables#perform",
        :constraints => {
          reviewable_id: /\d+/,
          action_id: /[a-z\_]+/,
        }
    put "review/:reviewable_id" => "reviewables#update", :constraints => { reviewable_id: /\d+/ }
    delete "review/:reviewable_id" => "reviewables#destroy",
           :constraints => {
             reviewable_id: /\d+/,
           }

    resources :reviewable_claimed_topics, only: %i[create destroy]

    get "session/sso" => "session#sso"
    get "session/sso_login" => "session#sso_login"
    get "session/sso_provider" => "session#sso_provider"
    get "session/current" => "session#current"
    get "session/csrf" => "session#csrf"
    get "session/hp" => "session#get_honeypot_value"
    get "session/email-login/:token" => "session#email_login_info"
    post "session/email-login/:token" => "session#email_login"
    get "session/otp/:token" => "session#one_time_password", :constraints => { token: /[0-9a-f]+/ }
    post "session/otp/:token" => "session#one_time_password", :constraints => { token: /[0-9a-f]+/ }
    get "session/2fa" => "session#second_factor_auth_show"
    post "session/2fa" => "session#second_factor_auth_perform"
    if Rails.env.test?
      post "session/2fa/test-action" => "session#test_second_factor_restricted_route"
    end
    get "session/passkey/challenge" => "session#passkey_challenge"
    post "session/passkey/auth" => "session#passkey_login"
    get "session/scopes" => "session#scopes"
    get "composer/mentions" => "composer#mentions"
    get "composer_messages" => "composer_messages#index"
    get "composer_messages/user_not_seen_in_a_while" => "composer_messages#user_not_seen_in_a_while"

    post "login" => "static#enter"

    get "login" => "static#show", :id => "login"
    get "login-preferences" => "static#show", :id => "login"
    get "signup" => "static#show", :id => "signup"
    get "password-reset" => "static#show", :id => "password_reset"
    get "privacy" => "static#show", :id => "privacy", :as => "privacy"
    get "tos" => "static#show", :id => "tos", :as => "tos"
    get "faq" => "static#show", :id => "faq"
    %w[guidelines rules conduct].each do |guidelines_alias|
      get guidelines_alias => "static#show", :id => "guidelines", :as => guidelines_alias
    end

    get "my/*path", to: "users#my_redirect"
    get ".well-known/change-password",
        to: redirect(relative_url_root + "my/preferences/security", status: 302)

    get "user-cards" => "users#cards", :format => :json
    get "directory-columns" => "directory_columns#index", :format => :json
    get "edit-directory-columns" => "edit_directory_columns#index", :format => :json
    put "edit-directory-columns" => "edit_directory_columns#update", :format => :json

    %w[users u].each_with_index do |root_path, index|
      get "#{root_path}" => "users#index", :constraints => { format: "html" }

      resources :users, only: %i[create], path: root_path do
        collection do
          get "check_username"
          get "check_email"
        end
      end

      get "#{root_path}/trusted-session" => "users#trusted_session"
      post "#{root_path}/confirm-session" => "users#confirm_session"

      post "#{root_path}/second_factors" => "users#list_second_factors"
      put "#{root_path}/second_factor" => "users#update_second_factor"

      post "#{root_path}/create_second_factor_security_key" =>
             "users#create_second_factor_security_key"
      post "#{root_path}/register_second_factor_security_key" =>
             "users#register_second_factor_security_key"
      put "#{root_path}/security_key" => "users#update_security_key"
      post "#{root_path}/create_second_factor_totp" => "users#create_second_factor_totp"
      post "#{root_path}/enable_second_factor_totp" => "users#enable_second_factor_totp"
      put "#{root_path}/disable_second_factor" => "users#disable_second_factor"

      put "#{root_path}/second_factors_backup" => "users#create_second_factor_backup"

      post "#{root_path}/create_passkey" => "users#create_passkey"
      post "#{root_path}/register_passkey" => "users#register_passkey"
      put "#{root_path}/rename_passkey/:id" => "users#rename_passkey"
      delete "#{root_path}/delete_passkey/:id" => "users#delete_passkey"

      put "#{root_path}/update-activation-email" => "users#update_activation_email"
      post "#{root_path}/email-login" => "users#email_login"
      get "#{root_path}/admin-login" => "users#admin_login"
      put "#{root_path}/admin-login" => "users#admin_login"
      post "#{root_path}/toggle-anon" => "users#toggle_anon"
      post "#{root_path}/read-faq" => "users#read_faq"
      get "#{root_path}/recent-searches" => "users#recent_searches",
          :constraints => {
            format: "json",
          }
      delete "#{root_path}/recent-searches" => "users#reset_recent_searches",
             :constraints => {
               format: "json",
             }
      get "#{root_path}/search/users" => "users#search_users"

      get(
        { "#{root_path}/account-created/" => "users#account_created" }.merge(
          index == 1 ? { as: :users_account_created } : { as: :old_account_created },
        ),
      )

      get "#{root_path}/account-created/resent" => "users#account_created"
      get "#{root_path}/account-created/edit-email" => "users#account_created"
      get(
        { "#{root_path}/password-reset/:token" => "users#password_reset_show" }.merge(
          index == 1 ? { as: :password_reset_token } : {},
        ),
      )
      get "#{root_path}/confirm-email-token/:token" => "users#confirm_email_token",
          :constraints => {
            format: "json",
          }
      put "#{root_path}/password-reset/:token" => "users#password_reset_update"
      get "#{root_path}/activate-account/:token" => "users#activate_account"
      put(
        { "#{root_path}/activate-account/:token" => "users#perform_account_activation" }.merge(
          index == 1 ? { as: "perform_activate_account" } : {},
        ),
      )

      get "#{root_path}/confirm-old-email/:token" => "users_email#show_confirm_old_email"
      put "#{root_path}/confirm-old-email/:token" => "users_email#confirm_old_email"

      get "#{root_path}/confirm-new-email/:token" => "users_email#show_confirm_new_email"
      put "#{root_path}/confirm-new-email/:token" => "users_email#confirm_new_email"

      get(
        {
          "#{root_path}/confirm-admin/:token" => "users#confirm_admin",
          :constraints => {
            token: /[0-9a-f]+/,
          },
        }.merge(index == 1 ? { as: "confirm_admin" } : {}),
      )
      post "#{root_path}/confirm-admin/:token" => "users#confirm_admin",
           :constraints => {
             token: /[0-9a-f]+/,
           }
      get "#{root_path}/:username/private-messages" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/private-messages/:filter" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/messages" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/messages/:filter" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/messages/group/:group_name" => "users#show",
          :constraints => {
            username: RouteFormat.username,
            group_name: RouteFormat.username,
          }
      get "#{root_path}/:username/messages/group/:group_name/:filter" => "users#show",
          :constraints => {
            username: RouteFormat.username,
            group_name: RouteFormat.username,
          }
      get "#{root_path}/:username/messages/tags/:tag_id" => "list#private_messages_tag",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username.json" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          },
          :defaults => {
            format: :json,
          }
      get(
        {
          "#{root_path}/:username" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          },
        }.merge(index == 1 ? { as: "user" } : {}),
      )
      put "#{root_path}/:username" => "users#update",
          :constraints => {
            username: RouteFormat.username,
          },
          :defaults => {
            format: :json,
          }
      get "#{root_path}/:username/emails" => "users#check_emails",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/sso-email" => "users#check_sso_email",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/sso-payload" => "users#check_sso_payload",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/email" => "users_email#index",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/account" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/security" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/profile" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/emails" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      put "#{root_path}/:username/preferences/primary-email" => "users#update_primary_email",
          :format => :json,
          :constraints => {
            username: RouteFormat.username,
          }
      delete "#{root_path}/:username/preferences/email" => "users#destroy_email",
             :constraints => {
               username: RouteFormat.username,
             }
      get "#{root_path}/:username/preferences/notifications" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/tracking" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/users" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/tags" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/interface" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/navigation-menu" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/apps" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      post "#{root_path}/:username/preferences/email" => "users_email#create",
           :constraints => {
             username: RouteFormat.username,
           }
      put "#{root_path}/:username/preferences/email" => "users_email#update",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/badge_title" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      put "#{root_path}/:username/preferences/badge_title" => "users#badge_title",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/username" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      put "#{root_path}/:username/preferences/username" => "users#username",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/preferences/second-factor" => "users#preferences",
          :constraints => {
            username: RouteFormat.username,
          }
      delete "#{root_path}/:username/preferences/user_image" => "users#destroy_user_image",
             :constraints => {
               username: RouteFormat.username,
             }
      put "#{root_path}/:username/preferences/avatar/pick" => "users#pick_avatar",
          :constraints => {
            username: RouteFormat.username,
          }
      put "#{root_path}/:username/preferences/avatar/select" => "users#select_avatar",
          :constraints => {
            username: RouteFormat.username,
          }
      post "#{root_path}/:username/preferences/revoke-account" => "users#revoke_account",
           :constraints => {
             username: RouteFormat.username,
           }
      post "#{root_path}/:username/preferences/revoke-auth-token" => "users#revoke_auth_token",
           :constraints => {
             username: RouteFormat.username,
           }
      get "#{root_path}/:username/staff-info" => "users#staff_info",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/summary" => "users#summary",
          :constraints => {
            username: RouteFormat.username,
          }
      put "#{root_path}/:username/notification_level" => "users#notification_level",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/invited" => "users#invited",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/invited/:filter" => "users#invited",
          :constraints => {
            username: RouteFormat.username,
          }
      post "#{root_path}/action/send_activation_email" => "users#send_activation_email"
      get "#{root_path}/:username/summary" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/activity/topics.rss" => "list#user_topics_feed",
          :format => :rss,
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/activity.rss" => "posts#user_posts_feed",
          :format => :rss,
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/activity.json" => "posts#user_posts_feed",
          :format => :json,
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/activity" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/activity/:filter" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/badges" => "users#badges",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/bookmarks" => "users#bookmarks",
          :constraints => {
            username: RouteFormat.username,
            format: /(json|ics)/,
          }
      get "#{root_path}/:username/user-menu-bookmarks" => "users#user_menu_bookmarks",
          :constraints => {
            username: RouteFormat.username,
            format: :json,
          }
      get "#{root_path}/:username/user-menu-private-messages" => "users#user_menu_messages",
          :constraints => {
            username: RouteFormat.username,
            format: :json,
          }
      get "#{root_path}/:username/notifications" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/notifications/:filter" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          }
      delete "#{root_path}/:username" => "users#destroy",
             :constraints => {
               username: RouteFormat.username,
             }
      get "#{root_path}/by-external/:external_id" => "users#show",
          :constraints => {
            external_id: %r{[^/]+},
          }
      get "#{root_path}/by-external/:external_provider/:external_id" => "users#show",
          :constraints => {
            external_id: %r{[^/]+},
          }
      get "#{root_path}/:username/deleted-posts" => "users#show",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/topic-tracking-state" => "users#topic_tracking_state",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/private-message-topic-tracking-state" =>
            "users#private_message_topic_tracking_state",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/profile-hidden" => "users#profile_hidden"
      put "#{root_path}/:username/feature-topic" => "users#feature_topic",
          :constraints => {
            username: RouteFormat.username,
          }
      put "#{root_path}/:username/clear-featured-topic" => "users#clear_featured_topic",
          :constraints => {
            username: RouteFormat.username,
          }
      get "#{root_path}/:username/card.json" => "users#show_card",
          :format => :json,
          :constraints => {
            username: RouteFormat.username,
          }
    end

    get "user-badges/:username.json" => "user_badges#username",
        :constraints => {
          username: RouteFormat.username,
        },
        :defaults => {
          format: :json,
        }
    get "user-badges/:username" => "user_badges#username",
        :constraints => {
          username: RouteFormat.username,
        }

    post "user_avatar/:username/refresh_gravatar" => "user_avatars#refresh_gravatar",
         :constraints => {
           username: RouteFormat.username,
         }
    get "letter_avatar/:username/:size/:version.png" => "user_avatars#show_letter",
        :constraints => {
          hostname: /[\w\.-]+/,
          size: /\d+/,
          username: RouteFormat.username,
          format: :png,
        }
    get "user_avatar/:hostname/:username/:size/:version.png" => "user_avatars#show",
        :constraints => {
          hostname: /[\w\.-]+/,
          size: /\d+/,
          username: RouteFormat.username,
          format: :png,
        }

    get "letter_avatar_proxy/:version/letter/:letter/:color/:size.png" =>
          "user_avatars#show_proxy_letter",
        :constraints => {
          format: :png,
        }

    get "svg-sprite/:hostname/svg-:theme_id-:version.js" => "svg_sprite#show",
        :constraints => {
          hostname: /[\w\.-]+/,
          version: /\h{40}/,
          theme_id: /([0-9]+)?/,
          format: :js,
        }
    get "svg-sprite/search/:keyword" => "svg_sprite#search",
        :format => false,
        :constraints => {
          keyword: /[-a-z0-9\s\%]+/,
        }
    get "svg-sprite/picker-search" => "svg_sprite#icon_picker_search",
        :defaults => {
          format: :json,
        }
    get "svg-sprite/:hostname/icon(/:color)/:name.svg" => "svg_sprite#svg_icon",
        :constraints => {
          hostname: /[\w\.-]+/,
          name: /[-a-z0-9\s\%]+/,
          color: /(\h{3}{1,2})/,
          format: :svg,
        }

    get "highlight-js/:hostname/:version.js" => "highlight_js#show",
        :constraints => {
          hostname: /[\w\.-]+/,
          format: :js,
        }

    get "stylesheets/:name" => "stylesheets#show_source_map",
        :constraints => {
          name: /[-a-z0-9_]+/,
          format: /css\.map/,
        },
        :format => true
    get "stylesheets/:name" => "stylesheets#show",
        :constraints => {
          name: /[-a-z0-9_]+/,
          format: "css",
        },
        :format => true
    get "color-scheme-stylesheet/:id(/:theme_id)" => "stylesheets#color_scheme",
        :constraints => {
          format: :json,
        }
    get "theme-javascripts/:digest" => "theme_javascripts#show",
        :constraints => {
          digest: /\h{40}/,
          format: :js,
        },
        :format => true
    get "theme-javascripts/:digest" => "theme_javascripts#show_map",
        :constraints => {
          digest: /\h{40}/,
          format: :map,
        },
        :format => true
    get "theme-javascripts/tests/:theme_id-:digest.js" => "theme_javascripts#show_tests"

    post "uploads/lookup-metadata" => "uploads#metadata"
    post "uploads" => "uploads#create"
    post "uploads/lookup-urls" => "uploads#lookup_urls"

    # direct to s3 uploads
    post "uploads/generate-presigned-put" => "uploads#generate_presigned_put", :format => :json
    post "uploads/complete-external-upload" => "uploads#complete_external_upload", :format => :json

    # multipart uploads
    post "uploads/create-multipart" => "uploads#create_multipart", :format => :json
    post "uploads/complete-multipart" => "uploads#complete_multipart", :format => :json
    post "uploads/abort-multipart" => "uploads#abort_multipart", :format => :json
    post "uploads/batch-presign-multipart-parts" => "uploads#batch_presign_multipart_parts",
         :format => :json

    # used to download original images
    get "uploads/:site/:sha(.:extension)" => "uploads#show",
        :constraints => {
          site: /\w+/,
          sha: /\h{40}/,
          extension: /[a-z0-9\._]+/i,
        }
    get "uploads/short-url/:base62(.:extension)" => "uploads#show_short",
        :constraints => {
          site: /\w+/,
          base62: /[a-zA-Z0-9]+/,
          extension: /[a-zA-Z0-9\._-]+/i,
        },
        :as => :upload_short
    # used to download attachments
    get "uploads/:site/original/:tree:sha(.:extension)" => "uploads#show",
        :constraints => {
          site: /\w+/,
          tree: %r{([a-z0-9]+/)+}i,
          sha: /\h{40}/,
          extension: /[a-z0-9\._]+/i,
        }
    if Rails.env.test?
      get "uploads/:site/test_:index/original/:tree:sha(.:extension)" => "uploads#show",
          :constraints => {
            site: /\w+/,
            index: /\d+/,
            tree: %r{([a-z0-9]+/)+}i,
            sha: /\h{40}/,
            extension: /[a-z0-9\._]+/i,
          }
    end
    # used to download attachments (old route)
    get "uploads/:site/:id/:sha" => "uploads#show",
        :constraints => {
          site: /\w+/,
          id: /\d+/,
          sha: /\h{16}/,
          format: /.*/,
        }

    # NOTE: secure-media-uploads is the old form, all new URLs generated for
    # secure uploads will be secure-uploads, this is left in for backwards
    # compat without needing to rebake all posts for each site.
    get "secure-media-uploads/*path(.:extension)" => "uploads#_show_secure_deprecated",
        :constraints => {
          extension: /[a-z0-9\._]+/i,
        }
    get "secure-uploads/*path(.:extension)" => "uploads#show_secure",
        :constraints => {
          extension: /[a-z0-9\._]+/i,
        }

    get "posts" => "posts#latest", :id => "latest_posts", :constraints => { format: /(json|rss)/ }
    get "private-posts" => "posts#latest",
        :id => "private_posts",
        :constraints => {
          format: /(json|rss)/,
        }
    get "posts/by_number/:topic_id/:post_number" => "posts#by_number"
    get "posts/by-date/:topic_id/:date" => "posts#by_date"
    get "posts/:id/reply-history" => "posts#reply_history"
    get "posts/:id/reply-ids" => "posts#reply_ids"
    get "posts/:username/deleted" => "posts#deleted_posts",
        :constraints => {
          username: RouteFormat.username,
        }
    get "posts/:username/pending" => "posts#pending",
        :constraints => {
          username: RouteFormat.username,
        }

    %w[groups g].each do |root_path|
      resources :groups,
                only: %i[index show new edit update],
                id: RouteFormat.username,
                path: root_path do
        get "posts.rss" => "groups#posts_feed", :format => :rss
        get "mentions.rss" => "groups#mentions_feed", :format => :rss

        get "members"
        get "posts"
        get "mentions"
        get "mentionable"
        get "messageable"
        get "logs" => "groups#histories"
        post "test_email_settings"

        collection do
          get "check-name" => "groups#check_name"
          get "custom/new" => "groups#new", :constraints => StaffConstraint.new
          get "search" => "groups#search"
        end

        member do
          %w[
            activity
            activity/:filter
            requests
            messages
            messages/inbox
            messages/archive
            manage
            manage/profile
            manage/members
            manage/membership
            manage/interaction
            manage/email
            manage/categories
            manage/tags
            manage/logs
          ].each { |path| get path => "groups#show" }

          get "permissions" => "groups#permissions"
          put "members" => "groups#add_members"
          put "owners" => "groups#add_owners"
          put "join" => "groups#join"
          delete "members" => "groups#remove_member"
          delete "leave" => "groups#leave"
          post "request_membership" => "groups#request_membership"
          put "handle_membership_request" => "groups#handle_membership_request"
          post "notifications" => "groups#set_notifications"
        end
      end
    end

    resources :associated_groups, only: %i[index], constraints: AdminConstraint.new

    post "slugs", to: "slugs#generate"

    # aliases so old API code works
    delete "admin/groups/:id/members" => "groups#remove_member", :constraints => AdminConstraint.new
    put "admin/groups/:id/members" => "groups#add_members", :constraints => AdminConstraint.new

    put "bookmarks/bulk"

    resources :posts, only: %i[show update create destroy], defaults: { format: "json" } do
      delete "bookmark", to: "posts#destroy_bookmark"
      put "wiki"
      put "post_type"
      put "rebake"
      put "unhide"
      put "locked"
      put "notice"
      get "replies"
      get "revisions/latest" => "posts#latest_revision"
      get "revisions/:revision" => "posts#revisions", :constraints => { revision: /\d+/ }
      put "revisions/:revision/hide" => "posts#hide_revision", :constraints => { revision: /\d+/ }
      put "revisions/:revision/show" => "posts#show_revision", :constraints => { revision: /\d+/ }
      put "revisions/:revision/revert" => "posts#revert", :constraints => { revision: /\d+/ }
      delete "revisions/permanently_delete" => "posts#permanently_delete_revisions"
      put "recover"
      collection do
        delete "destroy_many"
        put "merge_posts"
      end
    end

    resources :bookmarks, only: %i[create destroy update] do
      put "toggle_pin"
    end

    resources :notifications, only: %i[index create update destroy] do
      collection do
        put "mark-read" => "notifications#mark_read"
        # creating an alias cause the api was extended to mark a single notification
        # this allows us to cleanly target it
        put "read" => "notifications#mark_read"
        get "totals" => "notifications#totals"
      end
    end

    match "/auth/failure", to: "users/omniauth_callbacks#failure", via: %i[get post]
    get "/auth/:provider", to: "users/omniauth_callbacks#confirm_request"
    match "/auth/:provider/callback", to: "users/omniauth_callbacks#complete", via: %i[get post]
    get "/associate/:token",
        to: "users/associate_accounts#connect_info",
        constraints: {
          token: /\h{32}/,
        }
    post "/associate/:token",
         to: "users/associate_accounts#connect",
         constraints: {
           token: /\h{32}/,
         }

    post "/clicks/track" => "clicks#track", :as => "track_clicks"

    resources :post_action_users, only: %i[index]
    resources :post_readers, only: %i[index]
    resources :post_actions, only: %i[create destroy]
    resources :user_actions, only: %i[index show]

    resources :badges, only: [:index]
    get "/badges/:id(/:slug)" => "badges#show", :constraints => { format: /(json|html|rss)/ }
    resources :user_badges, only: %i[index create destroy] do
      put "toggle_favorite" => "user_badges#toggle_favorite", :constraints => { format: :json }
    end

    get "/c", to: redirect(relative_url_root + "categories")

    resources :categories, only: %i[index create update destroy]
    post "categories/reorder" => "categories#reorder"
    get "categories/find" => "categories#find"
    post "categories/search" => "categories#search"
    get "categories/hierarchical_search" => "categories#hierarchical_search"
    get "categories/:parent_category_id" => "categories#index"

    scope path: "category/:category_id" do
      post "/move" => "categories#move"
      post "/notifications" => "categories#set_notifications"
      put "/slug" => "categories#update_slug"
    end

    get "category/*path" => "categories#redirect"

    get "categories_and_latest" => "categories#categories_and_latest"
    get "categories_and_top" => "categories#categories_and_top"
    get "categories_and_hot" => "categories#categories_and_hot"

    get "c/:id/show" => "categories#show"
    get "c/:id/visible_groups" => "categories#visible_groups"

    get "c/*category_slug/find_by_slug" => "categories#find_by_slug"
    get "c/*category_slug/edit(/:tab)" => "categories#find_by_slug",
        :constraints => {
          format: "html",
        }
    get "/new-category" => "categories#show", :constraints => { format: "html" }

    get "c/*category_slug_path_with_id.rss" => "list#category_feed", :format => :rss
    scope path: "c/*category_slug_path_with_id" do
      get "/none" => "list#category_none_latest"

      TopTopic.periods.each do |period|
        get "/none/l/top/#{period}", to: redirect("/none/l/top?period=#{period}", status: 301)
        get "/l/top/#{period}", to: redirect("/l/top?period=#{period}", status: 301)
      end

      Discourse.filters.each do |filter|
        get "/none/l/#{filter}" => "list#category_none_#{filter}", :as => "category_none_#{filter}"
        get "/l/#{filter}" => "list#category_#{filter}", :as => "category_#{filter}"
      end

      get "/all" => "list#category_default",
          :as => "category_all",
          :constraints => {
            format: "html",
          }

      get "/subcategories" => "categories#index"

      get "/" => "list#category_default", :as => "category_default"
    end

    get "hashtags" => "hashtags#lookup"
    get "hashtags/by-ids" => "hashtags#by_ids"
    get "hashtags/search" => "hashtags#search"

    TopTopic.periods.each do |period|
      get "top/#{period}.rss", to: redirect("top.rss?period=#{period}", status: 301)
      get "top/#{period}.json", to: redirect("top.json?period=#{period}", status: 301)
      get "top/#{period}", to: redirect("top?period=#{period}", status: 301)
    end

    get "latest.rss" => "list#latest_feed", :format => :rss
    get "top.rss" => "list#top_feed", :format => :rss
    get "hot.rss" => "list#hot_feed", :format => :rss

    Discourse.filters.each { |filter| get "#{filter}" => "list##{filter}" }

    get "filter" => "list#filter"

    get "search/query" => "search#query"
    get "search" => "search#show"
    post "search/click" => "search#click"

    # Topics resource
    get "t/:id" => "topics#show"
    put "t/:topic_id" => "topics#update", :constraints => { topic_id: /\d+/ }
    delete "t/:id" => "topics#destroy"
    put "t/:id/archive-message" => "topics#archive_message"
    put "t/:id/move-to-inbox" => "topics#move_to_inbox"
    put "t/:id/convert-topic/:type" => "topics#convert_topic"
    put "t/:id/publish" => "topics#publish"
    put "t/:id/shared-draft" => "topics#update_shared_draft"
    put "t/:id/reset-bump-date/(:post_id)" => "topics#reset_bump_date",
        :constraints => {
          id: /\d+/,
          post_id: /\d+/,
        }
    put "topics/bulk"
    put "topics/reset-new" => "topics#reset_new"
    put "topics/pm-reset-new" => "topics#private_message_reset_new"
    post "topics/timings"

    get "topics/similar_to" => "similar_topics#index"
    resources :similar_topics, only: [:index]

    get "topics/feature_stats"

    scope "/topics", username: RouteFormat.username do
      get "created-by/:username" => "list#topics_by",
          :as => "topics_by",
          :defaults => {
            format: :json,
          }
      get "private-messages/:username" => "list#private_messages",
          :as => "topics_private_messages",
          :defaults => {
            format: :json,
          }
      get "private-messages-sent/:username" => "list#private_messages_sent",
          :as => "topics_private_messages_sent",
          :defaults => {
            format: :json,
          }
      get "private-messages-archive/:username" => "list#private_messages_archive",
          :as => "topics_private_messages_archive",
          :defaults => {
            format: :json,
          }
      get "private-messages-unread/:username" => "list#private_messages_unread",
          :as => "topics_private_messages_unread",
          :defaults => {
            format: :json,
          }
      get "private-messages-tags/:username/:tag_id.json" => "list#private_messages_tag",
          :as => "topics_private_messages_tag",
          :defaults => {
            format: :json,
          }
      get "private-messages-new/:username" => "list#private_messages_new",
          :as => "topics_private_messages_new",
          :defaults => {
            format: :json,
          }
      get "private-messages-warnings/:username" => "list#private_messages_warnings",
          :as => "topics_private_messages_warnings",
          :defaults => {
            format: :json,
          }
      get "groups/:group_name" => "list#group_topics",
          :as => "group_topics",
          :group_name => RouteFormat.username

      scope "/private-messages-group/:username", group_name: RouteFormat.username do
        get ":group_name.json" => "list#private_messages_group",
            :as => "topics_private_messages_group"
        get ":group_name/archive.json" => "list#private_messages_group_archive",
            :as => "topics_private_messages_group_archive"
        get ":group_name/new.json" => "list#private_messages_group_new",
            :as => "topics_private_messages_group_new"
        get ":group_name/unread.json" => "list#private_messages_group_unread",
            :as => "topics_private_messages_group_unread"
      end
    end

    get "embed/topics" => "embed#topics"
    get "embed/comments" => "embed#comments"
    get "embed/count" => "embed#count"
    get "embed/info" => "embed#info"

    get "new-topic" => "new_topic#index"
    get "new-message" => "new_topic#index"
    get "new-invite" => "new_invite#index"

    # Topic routes
    get "t/id_for/:slug" => "topics#id_for_slug"
    get "t/external_id/:external_id" => "topics#show_by_external_id",
        :format => :json,
        :constraints => {
          external_id: /[\w-]+/,
        }
    get "t/:slug/:topic_id/print" => "topics#show",
        :format => :html,
        :print => "true",
        :constraints => {
          topic_id: /\d+/,
        }
    get "t/:slug/:topic_id/wordpress" => "topics#wordpress", :constraints => { topic_id: /\d+/ }
    get "t/:topic_id/wordpress" => "topics#wordpress", :constraints => { topic_id: /\d+/ }

    get "t/:slug/:topic_id/summary" => "topics#show",
        :defaults => {
          summary: true,
        },
        :constraints => {
          topic_id: /\d+/,
        }
    get "t/:topic_id/summary" => "topics#show", :constraints => { topic_id: /\d+/ }
    put "t/:slug/:topic_id" => "topics#update", :constraints => { topic_id: /\d+/ }
    put "t/:slug/:topic_id/status" => "topics#status", :constraints => { topic_id: /\d+/ }
    put "t/:topic_id/status" => "topics#status", :constraints => { topic_id: /\d+/ }
    put "t/:topic_id/clear-pin" => "topics#clear_pin", :constraints => { topic_id: /\d+/ }
    put "t/:topic_id/re-pin" => "topics#re_pin", :constraints => { topic_id: /\d+/ }
    put "t/:topic_id/mute" => "topics#mute", :constraints => { topic_id: /\d+/ }
    put "t/:topic_id/unmute" => "topics#unmute", :constraints => { topic_id: /\d+/ }
    post "t/:topic_id/timer" => "topics#timer", :constraints => { topic_id: /\d+/ }
    put "t/:topic_id/make-banner" => "topics#make_banner", :constraints => { topic_id: /\d+/ }
    put "t/:topic_id/remove-banner" => "topics#remove_banner", :constraints => { topic_id: /\d+/ }
    put "t/:topic_id/remove-allowed-user" => "topics#remove_allowed_user",
        :constraints => {
          topic_id: /\d+/,
        }
    put "t/:topic_id/remove-allowed-group" => "topics#remove_allowed_group",
        :constraints => {
          topic_id: /\d+/,
        }
    put "t/:topic_id/recover" => "topics#recover", :constraints => { topic_id: /\d+/ }
    get "t/:topic_id/:post_number" => "topics#show",
        :constraints => {
          topic_id: /\d+/,
          post_number: /\d+/,
        }
    get "t/:topic_id/last" => "topics#show",
        :post_number => 99_999_999,
        :constraints => {
          topic_id: /\d+/,
        }
    get "t/:slug/:topic_id.rss" => "topics#feed",
        :format => :rss,
        :constraints => {
          topic_id: /\d+/,
        }
    get "t/:slug/:topic_id" => "topics#show", :constraints => { topic_id: /\d+/ }
    get "t/:slug/:topic_id/:post_number" => "topics#show",
        :constraints => {
          topic_id: /\d+/,
          post_number: /\d+/,
        }
    get "t/:slug/:topic_id/last" => "topics#show",
        :post_number => 99_999_999,
        :constraints => {
          topic_id: /\d+/,
        }
    get "t/:topic_id/posts" => "topics#posts", :constraints => { topic_id: /\d+/ }, :format => :json
    get "t/:topic_id/post_ids" => "topics#post_ids",
        :constraints => {
          topic_id: /\d+/,
        },
        :format => :json
    get "t/:topic_id/excerpts" => "topics#excerpts",
        :constraints => {
          topic_id: /\d+/,
        },
        :format => :json
    post "t/:topic_id/timings" => "topics#timings", :constraints => { topic_id: /\d+/ }
    post "t/:topic_id/invite" => "topics#invite", :constraints => { topic_id: /\d+/ }
    post "t/:topic_id/invite-group" => "topics#invite_group", :constraints => { topic_id: /\d+/ }
    post "t/:topic_id/move-posts" => "topics#move_posts", :constraints => { topic_id: /\d+/ }
    post "t/:topic_id/merge-topic" => "topics#merge_topic", :constraints => { topic_id: /\d+/ }
    post "t/:topic_id/change-owner" => "topics#change_post_owners",
         :constraints => {
           topic_id: /\d+/,
         }
    put "t/:topic_id/change-timestamp" => "topics#change_timestamps",
        :constraints => {
          topic_id: /\d+/,
        }
    delete "t/:topic_id/timings" => "topics#destroy_timings", :constraints => { topic_id: /\d+/ }
    put "t/:topic_id/bookmark" => "topics#bookmark", :constraints => { topic_id: /\d+/ }
    put "t/:topic_id/remove_bookmarks" => "topics#remove_bookmarks",
        :constraints => {
          topic_id: /\d+/,
        }
    put "t/:topic_id/tags" => "topics#update_tags", :constraints => { topic_id: /\d+/ }
    put "t/:topic_id/slow_mode" => "topics#set_slow_mode", :constraints => { topic_id: /\d+/ }

    post "t/:topic_id/notifications" => "topics#set_notifications",
         :constraints => {
           topic_id: /\d+/,
         }

    get "p/:post_id(/:user_id)" => "posts#short_link"
    get "/posts/:id/cooked" => "posts#cooked"
    get "/posts/:id/expand-embed" => "posts#expand_embed"
    get "/posts/:id/raw" => "posts#markdown_id"
    get "/posts/:id/raw-email" => "posts#raw_email"
    get "raw/:topic_id(/:post_number)" => "posts#markdown_num"

    resources :invites, only: %i[create update destroy]
    get "/invites/:id" => "invites#show", :constraints => { format: :html }
    post "invites/create-multiple" => "invites#create_multiple", :constraints => { format: :json }

    post "invites/upload_csv" => "invites#upload_csv"
    post "invites/destroy-all-expired" => "invites#destroy_all_expired"
    post "invites/reinvite" => "invites#resend_invite"
    post "invites/reinvite-all" => "invites#resend_all_invites"
    delete "invites" => "invites#destroy"
    put "invites/show/:id" => "invites#perform_accept_invitation", :as => "perform_accept_invite"
    get "invites/retrieve" => "invites#retrieve"

    post "/export_csv/export_entity" => "export_csv#export_entity",
         :as => "export_entity_export_csv_index"

    get "onebox" => "onebox#show"
    get "inline-onebox" => "inline_onebox#show"

    get "exception" => "list#latest"

    get "message-bus/poll" => "message_bus#poll"

    resources :drafts, only: %i[index create show destroy]

    get "/service-worker.js" => "static#service_worker_asset", :format => :js
    if service_worker_asset = Rails.application.assets_manifest.assets["service-worker.js"]
      # https://developers.google.com/web/fundamentals/codelabs/debugging-service-workers/
      # Normally the browser will wait until a user closes all tabs that contain the
      # current site before updating to a new Service Worker.
      # Support the old Service Worker path to avoid routing error filling up the
      # logs.
      get service_worker_asset => "static#service_worker_asset", :format => :js
    end

    get "cdn_asset/:site/*path" => "static#cdn_asset",
        :format => false,
        :constraints => {
          format: /.*/,
        }

    get "favicon/proxied" => "static#favicon", :format => false

    get "robots.txt" => "robots_txt#index"
    get "robots-builder.json" => "robots_txt#builder"
    get "offline.html" => "offline#index"
    get "manifest.webmanifest" => "metadata#manifest", :as => :manifest
    get "manifest.json" => "metadata#manifest"
    get ".well-known/assetlinks.json" => "metadata#app_association_android"
    get "apple-app-site-association" => "metadata#app_association_ios", :format => false
    get "opensearch" => "metadata#opensearch", :constraints => { format: :xml }

    scope "/tag/:tag_id" do
      constraints format: :json do
        get "/" => "tags#show", :as => "tag_show"
        get "/info" => "tags#info"
        get "/notifications" => "tags#notifications"
        put "/notifications" => "tags#update_notifications"
        put "/" => "tags#update"
        delete "/" => "tags#destroy"
        post "/synonyms" => "tags#create_synonyms"
        delete "/synonyms/:synonym_id" => "tags#destroy_synonym"

        Discourse.filters.each do |filter|
          get "/l/#{filter}" => "tags#show_#{filter}", :as => "tag_show_#{filter}"
        end
      end

      constraints format: :rss do
        get "/" => "tags#tag_feed"
      end
    end

    scope "/tags" do
      get "/" => "tags#index"
      get "/filter/list" => "tags#index"
      get "/filter/search" => "tags#search"
      get "/list" => "tags#list"
      get "/personal_messages/:username" => "tags#personal_messages",
          :constraints => {
            username: RouteFormat.username,
          }
      post "/upload" => "tags#upload"
      get "/unused" => "tags#list_unused"
      delete "/unused" => "tags#destroy_unused"

      constraints(tag_id: %r{[^/]+?}, format: /json|rss/) do
        scope path: "/c/*category_slug_path_with_id" do
          Discourse.filters.each do |filter|
            get "/none/:tag_id/l/#{filter}" => "tags#show_#{filter}",
                :as => "tag_category_none_show_#{filter}",
                :defaults => {
                  no_subcategories: true,
                }
            get "/all/:tag_id/l/#{filter}" => "tags#show_#{filter}",
                :as => "tag_category_all_show_#{filter}",
                :defaults => {
                  no_subcategories: false,
                }
          end

          get "/none/:tag_id" => "tags#show",
              :as => "tag_category_none_show",
              :defaults => {
                no_subcategories: true,
              }
          get "/all/:tag_id" => "tags#show",
              :as => "tag_category_all_show",
              :defaults => {
                no_subcategories: false,
              }

          Discourse.filters.each do |filter|
            get "/:tag_id/l/#{filter}" => "tags#show_#{filter}",
                :as => "tag_category_show_#{filter}"
          end

          get "/:tag_id" => "tags#show", :as => "tag_category_show"
        end

        get "/intersection/:tag_id/*additional_tag_ids" => "tags#show", :as => "tag_intersection"
      end

      get "*tag_id", to: redirect(relative_url_root + "tag/%{tag_id}")
    end

    resources :tag_groups, constraints: StaffConstraint.new, except: [:edit]
    get "/tag_groups/filter/search" => "tag_groups#search", :format => :json

    Discourse.filters.each do |filter|
      root to: "list##{filter}",
           constraints: HomePageConstraint.new("#{filter}"),
           as: "list_#{filter}"
    end

    get "/t/:topic_id/view-stats.json" => "topic_view_stats#index"

    # special case for categories
    root to: "categories#index",
         constraints: HomePageConstraint.new("categories"),
         as: "categories_index"

    root to: "finish_installation#index",
         constraints: HomePageConstraint.new("finish_installation"),
         as: "installation_redirect"

    root to: "custom_homepage#index",
         constraints: HomePageConstraint.new("custom"),
         as: "custom_index"

    get "/custom" => "custom_homepage#index"

    get "/user-api-key/new" => "user_api_keys#new"
    post "/user-api-key" => "user_api_keys#create"
    post "/user-api-key/revoke" => "user_api_keys#revoke"
    post "/user-api-key/undo-revoke" => "user_api_keys#undo_revoke"
    get "/user-api-key/otp" => "user_api_keys#otp"
    post "/user-api-key/otp" => "user_api_keys#create_otp"

    get "/user-api-key-client" => "user_api_key_clients#show"
    post "/user-api-key-client" => "user_api_key_clients#create"

    get "/safe-mode" => "safe_mode#index"
    post "/safe-mode" => "safe_mode#enter", :as => "safe_mode_enter"

    get "/theme-qunit" => "qunit#theme"
    get "/theme-tests", to: redirect("/theme-qunit")

    # This is a special route that is used when theme QUnit tests are run through testem which appends a testem_id to the
    # path. Unfortunately, testem's proxy support does not allow us to easily remove this from the path, so we have to
    # handle it here.
    if Rails.env.development?
      get "/testem-theme-qunit/:testem_id/theme-qunit" => "qunit#theme",
          :constraints => {
            testem_id: /\d+/,
          }
    end

    post "/push_notifications/subscribe" => "push_notification#subscribe"
    post "/push_notifications/unsubscribe" => "push_notification#unsubscribe"

    resources :csp_reports, only: [:create]

    get "/permalink-check", to: "permalinks#check"

    post "/do-not-disturb" => "do_not_disturb#create"
    delete "/do-not-disturb" => "do_not_disturb#destroy"

    post "/presence/update" => "presence#update"
    get "/presence/get" => "presence#get"

    get "user-status" => "user_status#get"
    put "user-status" => "user_status#set"
    delete "user-status" => "user_status#clear"

    resources :sidebar_sections, only: %i[index create update destroy]
    put "/sidebar_sections/reset/:id" => "sidebar_sections#reset"

    post "/pageview" => "pageview#index"

    get "*url", to: "permalinks#show", constraints: PermalinkConstraint.new

    get "/form-templates/:id" => "form_templates#show"
    get "/form-templates" => "form_templates#index"

    if Rails.env.test?
      # Routes that are only used for testing
      get "/test_net_http_timeouts" => "test_requests#test_net_http_timeouts"
    end
  end
end
