# frozen_string_literal: true

require "sidekiq/web"
require "mini_scheduler/web"
require 'freedom_patches/sidekiq/sidekiq_session_patch'

# The following constants have been replaced with `RouteFormat` and are deprecated.
USERNAME_ROUTE_FORMAT = /[%\w.\-]+?/ unless defined? USERNAME_ROUTE_FORMAT
BACKUP_ROUTE_FORMAT = /.+\.(sql\.gz|tar\.gz|tgz)/i unless defined? BACKUP_ROUTE_FORMAT

Discourse::Application.routes.draw do
  scope path: nil, constraints: { format: /(json|html|\*\/\*)/ } do
    relative_url_root = (defined?(Rails.configuration.relative_url_root) && Rails.configuration.relative_url_root) ? Rails.configuration.relative_url_root + '/' : '/'

  match "/404", to: "exceptions#not_found", via: [:get, :post]
  get "/404-body" => "exceptions#not_found_body"

  post "webhooks/aws" => "webhooks#aws"
  post "webhooks/mailgun"  => "webhooks#mailgun"
  post "webhooks/mailjet"  => "webhooks#mailjet"
  post "webhooks/mandrill" => "webhooks#mandrill"
  post "webhooks/postmark" => "webhooks#postmark"
  post "webhooks/sendgrid" => "webhooks#sendgrid"
  post "webhooks/sparkpost" => "webhooks#sparkpost"

  scope path: nil, constraints: { format: /.*/ } do
    Sidekiq::WebAction.prepend(SidekiqSessionPatch)
    if Rails.env.development?
      mount Sidekiq::Web => "/sidekiq"
      mount Logster::Web => "/logs"
    else
      # only allow sidekiq in master site
      mount Sidekiq::Web => "/sidekiq", constraints: AdminConstraint.new(require_master: true)
      mount Logster::Web => "/logs", constraints: AdminConstraint.new
    end
  end

  resources :about do
    collection do
      get "live_post_counts"
    end
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

  resources :directory_items

  get "site" => "site#site"
  namespace :site do
    get "settings"
    get "custom_html"
    get "banner"
    get "emoji"
  end

  get "site/basic-info" => 'site#basic_info'
  get "site/statistics" => 'site#statistics'
  get "site/selectable-avatars" => "site#selectable_avatars"

  get "srv/status" => "forums#status"

  get "wizard" => "wizard#index"
  get 'wizard/steps' => 'steps#index'
  get 'wizard/steps/:id' => "wizard#index"
  put 'wizard/steps/:id' => "steps#update"

  namespace :admin, constraints: StaffConstraint.new do
    get "" => "admin#index"

    get 'plugins' => 'plugins#index'

    resources :site_settings, constraints: AdminConstraint.new do
      collection do
        get "category/:id" => "site_settings#index"
      end

      put "user_count" => "site_settings#user_count"
    end

    get "reports" => "reports#index"
    get "reports/bulk" => "reports#bulk"
    get "reports/:type" => "reports#show"

    resources :groups, constraints: AdminConstraint.new do
      collection do
        get 'bulk'
        get 'bulk-complete' => 'groups#bulk'
        put 'bulk' => 'groups#bulk_perform'
        put "automatic_membership_count" => "groups#automatic_membership_count"
      end
      member do
        put "owners" => "groups#add_owners"
        delete "owners" => "groups#remove_owner"
      end
    end

    get "groups/:type" => "groups#show", constraints: AdminConstraint.new
    get "groups/:type/:id" => "groups#show", constraints: AdminConstraint.new

    resources :users, id: RouteFormat.username, except: [:show] do
      collection do
        get "list" => "users#index"
        get "list/:query" => "users#index"
        get "ip-info" => "users#ip_info"
        delete "delete-others-with-same-ip" => "users#delete_other_accounts_with_same_ip"
        get "total-others-with-same-ip" => "users#total_other_accounts_with_same_ip"
        put "approve-bulk" => "users#approve_bulk"
      end
      delete "penalty_history", constraints: AdminConstraint.new
      put "suspend"
      put "delete_posts_batch"
      put "unsuspend"
      put "revoke_admin", constraints: AdminConstraint.new
      put "grant_admin", constraints: AdminConstraint.new
      post "generate_api_key", constraints: AdminConstraint.new
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
      post "groups" => "users#add_group", constraints: AdminConstraint.new
      delete "groups/:group_id" => "users#remove_group", constraints: AdminConstraint.new
      get "badges"
      get "leader_requirements" => "users#tl3_requirements"
      get "tl3_requirements"
      put "anonymize"
      post "merge"
      post "reset_bounce_score"
      put "disable_second_factor"
    end
    get "users/:id.json" => 'users#show', defaults: { format: 'json' }
    get 'users/:id/:username' => 'users#show', constraints: { username: RouteFormat.username }
    get 'users/:id/:username/badges' => 'users#show'
    get 'users/:id/:username/tl3_requirements' => 'users#show'

    post "users/sync_sso" => "users#sync_sso", constraints: AdminConstraint.new

    resources :impersonate, constraints: AdminConstraint.new

    resources :email, constraints: AdminConstraint.new do
      collection do
        post "test"
        get "sent"
        get "skipped"
        get "bounced"
        get "received"
        get "rejected"
        get "/incoming/:id/raw" => "email#raw_email"
        get "/incoming/:id" => "email#incoming"
        get "/incoming_from_bounced/:id" => "email#incoming_from_bounced"
        get "preview-digest" => "email#preview_digest"
        get "send-digest" => "email#send_digest"
        get "smtp_should_reject"
        post "handle_mail"
        get "advanced-test"
        post "advanced-test" => "email#advanced_test"
      end
    end

    scope "/logs" do
      resources :staff_action_logs,     only: [:index]
      get 'staff_action_logs/:id/diff' => 'staff_action_logs#diff'
      resources :screened_emails,       only: [:index, :destroy]
      resources :screened_ip_addresses, only: [:index, :create, :update, :destroy] do
        collection do
          post "roll_up"
        end
      end
      resources :screened_urls,         only: [:index]
      resources :watched_words, only: [:index, :create, :update, :destroy] do
        collection do
          get "action/:id" => "watched_words#index"
          get "action/:id/download" => "watched_words#download"
          delete "action/:id" => "watched_words#clear_all"
        end
      end
      post "watched_words/upload" => "watched_words#upload"
      resources :search_logs,           only: [:index]
      get 'search_logs/term/' => 'search_logs#term'
    end

    get "/logs" => "staff_action_logs#index"

    get "customize" => "color_schemes#index", constraints: AdminConstraint.new
    get "customize/themes" => "themes#index", constraints: AdminConstraint.new
    get "customize/colors" => "color_schemes#index", constraints: AdminConstraint.new
    get "customize/colors/:id" => "color_schemes#index", constraints: AdminConstraint.new
    get "customize/permalinks" => "permalinks#index", constraints: AdminConstraint.new
    get "customize/embedding" => "embedding#show", constraints: AdminConstraint.new
    put "customize/embedding" => "embedding#update", constraints: AdminConstraint.new

    resources :themes, constraints: AdminConstraint.new

    post "themes/import" => "themes#import"
    post "themes/upload_asset" => "themes#upload_asset"
    post "themes/generate_key_pair" => "themes#generate_key_pair"
    get "themes/:id/preview" => "themes#preview"
    get "themes/:id/diff_local_changes" => "themes#diff_local_changes"
    put "themes/:id/setting" => "themes#update_single_setting"

    scope "/customize", constraints: AdminConstraint.new do
      resources :user_fields, constraints: AdminConstraint.new
      resources :emojis, constraints: AdminConstraint.new

      get 'themes/:id/:target/:field_name/edit' => 'themes#index'
      get 'themes/:id' => 'themes#index'
      get "themes/:id/export" => "themes#export"

      # They have periods in their URLs often:
      get 'site_texts'             => 'site_texts#index'
      get 'site_texts/:id.json'    => 'site_texts#show',   constraints: { id: /[\w.\-\+\%\&]+/i }
      get 'site_texts/:id'         => 'site_texts#show',   constraints: { id: /[\w.\-\+\%\&]+/i }
      put 'site_texts/:id.json'    => 'site_texts#update', constraints: { id: /[\w.\-\+\%\&]+/i }
      put 'site_texts/:id'         => 'site_texts#update', constraints: { id: /[\w.\-\+\%\&]+/i }
      delete 'site_texts/:id.json' => 'site_texts#revert', constraints: { id: /[\w.\-\+\%\&]+/i }
      delete 'site_texts/:id'      => 'site_texts#revert', constraints: { id: /[\w.\-\+\%\&]+/i }

      get 'reseed' => 'site_texts#get_reseed_options'
      post 'reseed' => 'site_texts#reseed'

      get 'email_templates'          => 'email_templates#index'
      get 'email_templates/(:id)'    => 'email_templates#show',   constraints: { id: /[0-9a-z_.]+/ }
      put 'email_templates/(:id)'    => 'email_templates#update', constraints: { id: /[0-9a-z_.]+/ }
      delete 'email_templates/(:id)' => 'email_templates#revert', constraints: { id: /[0-9a-z_.]+/ }

      get 'robots' => 'robots_txt#show'
      put 'robots.json' => 'robots_txt#update'
      delete 'robots.json' => 'robots_txt#reset'

      resource :email_style, only: [:show, :update]
      get 'email_style/:field' => 'email_styles#show', constraints: { field: /html|css/ }
    end

    resources :embeddable_hosts, constraints: AdminConstraint.new
    resources :color_schemes, constraints: AdminConstraint.new

    resources :permalinks, constraints: AdminConstraint.new

    get "version_check" => "versions#show"

    get "dashboard" => "dashboard#index"
    get "dashboard/general" => "dashboard#general"
    get "dashboard/moderation" => "dashboard#moderation"
    get "dashboard/security" => "dashboard#security"
    get "dashboard/reports" => "dashboard#reports"

    resources :dashboard, only: [:index] do
      collection do
        get "problems"
      end
    end

    resources :api, only: [:index], constraints: AdminConstraint.new do
      collection do
        resources :keys, controller: 'api', only: [:index, :show, :update, :create, :destroy] do
          member do
            post "revoke" => "api#revoke_key"
            post "undo-revoke" => "api#undo_revoke_key"
          end
        end

        resources :web_hooks
        get 'web_hook_events/:id' => 'web_hooks#list_events', as: :web_hook_events
        get 'web_hooks/:id/events' => 'web_hooks#list_events'
        get 'web_hooks/:id/events/bulk' => 'web_hooks#bulk_events'
        post 'web_hooks/:web_hook_id/events/:event_id/redeliver' => 'web_hooks#redeliver_event'
        post 'web_hooks/:id/ping' => 'web_hooks#ping'
      end
    end

    resources :backups, only: [:index, :create], constraints: AdminConstraint.new do
      member do
        get "" => "backups#show", constraints: { id: RouteFormat.backup }
        put "" => "backups#email", constraints: { id: RouteFormat.backup }
        delete "" => "backups#destroy", constraints: { id: RouteFormat.backup }
        post "restore" => "backups#restore", constraints: { id: RouteFormat.backup }
      end
      collection do
        get "logs" => "backups#logs"
        get "status" => "backups#status"
        delete "cancel" => "backups#cancel"
        post "rollback" => "backups#rollback"
        put "readonly" => "backups#readonly"
        get "upload" => "backups#check_backup_chunk"
        post "upload" => "backups#upload_backup_chunk"
        get "upload_url" => "backups#create_upload_url"
      end
    end

    resources :badges, constraints: AdminConstraint.new do
      collection do
        get "/award/:badge_id" => "badges#award"
        post "/award/:badge_id" => "badges#mass_award"
        get "types" => "badges#badge_types"
        post "badge_groupings" => "badges#save_badge_groupings"
        post "preview" => "badges#preview"
      end
    end

  end # admin namespace

  get "email_preferences" => "email#preferences_redirect", :as => "email_preferences_redirect"

  get "email/unsubscribe/:key" => "email#unsubscribe", as: "email_unsubscribe"
  get "email/unsubscribed" => "email#unsubscribed", as: "email_unsubscribed"
  post "email/unsubscribe/:key" => "email#perform_unsubscribe", as: "email_perform_unsubscribe"

  get "extra-locales/:bundle" => "extra_locales#show"

  resources :session, id: RouteFormat.username, only: [:create, :destroy, :become] do
    if !Rails.env.production?
      get 'become'
    end

    collection do
      post "forgot_password"
    end
  end

  get "review" => "reviewables#index" # For ember app
  get "review/:reviewable_id" => "reviewables#show", constraints: { reviewable_id: /\d+/ }
  get "review/:reviewable_id/explain" => "reviewables#explain", constraints: { reviewable_id: /\d+/ }
  get "review/topics" => "reviewables#topics"
  get "review/settings" => "reviewables#settings"
  put "review/settings" => "reviewables#settings"
  put "review/:reviewable_id/perform/:action_id" => "reviewables#perform", constraints: {
    reviewable_id: /\d+/,
    action_id: /[a-z\_]+/
  }
  put "review/:reviewable_id" => "reviewables#update", constraints: { reviewable_id: /\d+/ }
  delete "review/:reviewable_id" => "reviewables#destroy", constraints: { reviewable_id: /\d+/ }

  resources :reviewable_claimed_topics

  get "session/sso" => "session#sso"
  get "session/sso_login" => "session#sso_login"
  get "session/sso_provider" => "session#sso_provider"
  get "session/current" => "session#current"
  get "session/csrf" => "session#csrf"
  get "session/email-login/:token" => "session#email_login_info"
  post "session/email-login/:token" => "session#email_login"
  get "session/otp/:token" => "session#one_time_password", constraints: { token: /[0-9a-f]+/ }
  post "session/otp/:token" => "session#one_time_password", constraints: { token: /[0-9a-f]+/ }
  get "composer_messages" => "composer_messages#index"

  resources :static
  post "login" => "static#enter"
  get "login" => "static#show", id: "login"
  get "password-reset" => "static#show", id: "password_reset"
  get "faq" => "static#show", id: "faq"
  get "tos" => "static#show", id: "tos", as: 'tos'
  get "privacy" => "static#show", id: "privacy", as: 'privacy'
  get "signup" => "static#show", id: "signup"
  get "login-preferences" => "static#show", id: "login"

  %w{guidelines rules conduct}.each do |faq_alias|
    get faq_alias => "static#show", id: "guidelines", as: faq_alias
  end

  get "my/*path", to: 'users#my_redirect'
  get "user_preferences" => "users#user_preferences_redirect"
  get ".well-known/change-password", to: redirect(relative_url_root + 'my/preferences/account', status: 302)

  get "user-cards" => "users#cards", format: :json

  %w{users u}.each_with_index do |root_path, index|
    get "#{root_path}" => "users#index", constraints: { format: 'html' }

    resources :users, except: [:index, :new, :show, :update, :destroy], path: root_path do
      collection do
        get "check_username"
        get "is_local_username"
      end
    end

    post "#{root_path}/second_factors" => "users#list_second_factors"
    put "#{root_path}/second_factor" => "users#update_second_factor"

    post "#{root_path}/create_second_factor_security_key" => "users#create_second_factor_security_key"
    post "#{root_path}/register_second_factor_security_key" => "users#register_second_factor_security_key"
    put "#{root_path}/security_key" => "users#update_security_key"
    post "#{root_path}/create_second_factor_totp" => "users#create_second_factor_totp"
    post "#{root_path}/enable_second_factor_totp" => "users#enable_second_factor_totp"
    put "#{root_path}/disable_second_factor" => "users#disable_second_factor"

    put "#{root_path}/second_factors_backup" => "users#create_second_factor_backup"

    put "#{root_path}/update-activation-email" => "users#update_activation_email"
    get "#{root_path}/hp" => "users#get_honeypot_value"
    post "#{root_path}/email-login" => "users#email_login"
    get "#{root_path}/admin-login" => "users#admin_login"
    put "#{root_path}/admin-login" => "users#admin_login"
    post "#{root_path}/toggle-anon" => "users#toggle_anon"
    post "#{root_path}/read-faq" => "users#read_faq"
    get "#{root_path}/search/users" => "users#search_users"

    get({ "#{root_path}/account-created/" => "users#account_created" }.merge(index == 1 ? { as: :users_account_created } : { as: :old_account_created }))

    get "#{root_path}/account-created/resent" => "users#account_created"
    get "#{root_path}/account-created/edit-email" => "users#account_created"
    get({ "#{root_path}/password-reset/:token" => "users#password_reset_show" }.merge(index == 1 ? { as: :password_reset_token } : {}))
    get "#{root_path}/confirm-email-token/:token" => "users#confirm_email_token", constraints: { format: 'json' }
    put "#{root_path}/password-reset/:token" => "users#password_reset_update"
    get "#{root_path}/activate-account/:token" => "users#activate_account"
    put({ "#{root_path}/activate-account/:token" => "users#perform_account_activation" }.merge(index == 1 ? { as: 'perform_activate_account' } : {}))

    get "#{root_path}/confirm-old-email/:token" => "users_email#show_confirm_old_email"
    put "#{root_path}/confirm-old-email" => "users_email#confirm_old_email"

    get "#{root_path}/confirm-new-email/:token" => "users_email#show_confirm_new_email"
    put "#{root_path}/confirm-new-email" => "users_email#confirm_new_email"

    get({
      "#{root_path}/confirm-admin/:token" => "users#confirm_admin",
      constraints: { token: /[0-9a-f]+/ }
    }.merge(index == 1 ? { as: 'confirm_admin' } : {}))
    post "#{root_path}/confirm-admin/:token" => "users#confirm_admin", constraints: { token: /[0-9a-f]+/ }
    get "#{root_path}/:username/private-messages" => "user_actions#private_messages", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/private-messages/:filter" => "user_actions#private_messages", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/messages" => "user_actions#private_messages", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/messages/:filter" => "user_actions#private_messages", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/messages/group/:group_name" => "user_actions#private_messages", constraints: { username: RouteFormat.username, group_name: RouteFormat.username }
    get "#{root_path}/:username/messages/group/:group_name/archive" => "user_actions#private_messages", constraints: { username: RouteFormat.username, group_name: RouteFormat.username }
    get "#{root_path}/:username/messages/tags/:tag_id" => "user_actions#private_messages", constraints: StaffConstraint.new
    get "#{root_path}/:username.json" => "users#show", constraints: { username: RouteFormat.username }, defaults: { format: :json }
    get({ "#{root_path}/:username" => "users#show", constraints: { username: RouteFormat.username } }.merge(index == 1 ? { as: 'user' } : {}))
    put "#{root_path}/:username" => "users#update", constraints: { username: RouteFormat.username }, defaults: { format: :json }
    get "#{root_path}/:username/emails" => "users#check_emails", constraints: { username: RouteFormat.username }
    get({ "#{root_path}/:username/preferences" => "users#preferences", constraints: { username: RouteFormat.username } }.merge(index == 1 ? { as: :email_preferences } : {}))
    get "#{root_path}/:username/preferences/email" => "users_email#index", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/account" => "users#preferences", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/profile" => "users#preferences", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/emails" => "users#preferences", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/notifications" => "users#preferences", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/categories" => "users#preferences", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/users" => "users#preferences", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/tags" => "users#preferences", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/interface" => "users#preferences", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/apps" => "users#preferences", constraints: { username: RouteFormat.username }
    put "#{root_path}/:username/preferences/email" => "users_email#update", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/badge_title" => "users#preferences", constraints: { username: RouteFormat.username }
    put "#{root_path}/:username/preferences/badge_title" => "users#badge_title", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/username" => "users#preferences", constraints: { username: RouteFormat.username }
    put "#{root_path}/:username/preferences/username" => "users#username", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/second-factor" => "users#preferences", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/preferences/second-factor-backup" => "users#preferences", constraints: { username: RouteFormat.username }
    delete "#{root_path}/:username/preferences/user_image" => "users#destroy_user_image", constraints: { username: RouteFormat.username }
    put "#{root_path}/:username/preferences/avatar/pick" => "users#pick_avatar", constraints: { username: RouteFormat.username }
    put "#{root_path}/:username/preferences/avatar/select" => "users#select_avatar", constraints: { username: RouteFormat.username }
    post "#{root_path}/:username/preferences/revoke-account" => "users#revoke_account", constraints: { username: RouteFormat.username }
    post "#{root_path}/:username/preferences/revoke-auth-token" => "users#revoke_auth_token", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/staff-info" => "users#staff_info", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/summary" => "users#summary", constraints: { username: RouteFormat.username }
    put "#{root_path}/:username/notification_level" => "users#notification_level", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/invited" => "users#invited", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/invited_count" => "users#invited_count", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/invited/:filter" => "users#invited", constraints: { username: RouteFormat.username }
    post "#{root_path}/action/send_activation_email" => "users#send_activation_email"
    get "#{root_path}/:username/summary" => "users#show", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/activity/topics.rss" => "list#user_topics_feed", format: :rss, constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/activity.rss" => "posts#user_posts_feed", format: :rss, constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/activity.json" => "posts#user_posts_feed", format: :json, constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/activity" => "users#show", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/activity/:filter" => "users#show", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/badges" => "users#badges", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/bookmarks" => "users#bookmarks", constraints: { username: RouteFormat.username, format: /(json|ics)/ }
    get "#{root_path}/:username/notifications" => "users#show", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/notifications/:filter" => "users#show", constraints: { username: RouteFormat.username }
    delete "#{root_path}/:username" => "users#destroy", constraints: { username: RouteFormat.username }
    get "#{root_path}/by-external/:external_id" => "users#show", constraints: { external_id: /[^\/]+/ }
    get "#{root_path}/:username/flagged-posts" => "users#show", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/deleted-posts" => "users#show", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/topic-tracking-state" => "users#topic_tracking_state", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/profile-hidden" => "users#profile_hidden"
    put "#{root_path}/:username/feature-topic" => "users#feature_topic", constraints: { username: RouteFormat.username }
    put "#{root_path}/:username/clear-featured-topic" => "users#clear_featured_topic", constraints: { username: RouteFormat.username }
    get "#{root_path}/:username/card.json" => "users#show_card", format: :json, constraints: { username: RouteFormat.username }
  end

  get "user-badges/:username.json" => "user_badges#username", constraints: { username: RouteFormat.username }, defaults: { format: :json }
  get "user-badges/:username" => "user_badges#username", constraints: { username: RouteFormat.username }

  post "user_avatar/:username/refresh_gravatar" => "user_avatars#refresh_gravatar", constraints: { username: RouteFormat.username }
  get "letter_avatar/:username/:size/:version.png" => "user_avatars#show_letter", constraints: { hostname: /[\w\.-]+/, size: /\d+/, username: RouteFormat.username, format: :png }
  get "user_avatar/:hostname/:username/:size/:version.png" => "user_avatars#show", constraints: { hostname: /[\w\.-]+/, size: /\d+/, username: RouteFormat.username, format: :png }

  get "letter_avatar_proxy/:version/letter/:letter/:color/:size.png" => "user_avatars#show_proxy_letter", constraints: { format: :png }

  get "svg-sprite/:hostname/svg-:theme_ids-:version.js" => "svg_sprite#show", constraints: { hostname: /[\w\.-]+/, version: /\h{40}/, theme_ids: /([0-9]+(,[0-9]+)*)?/, format: :js }
  get "svg-sprite/search/:keyword" => "svg_sprite#search", format: false, constraints: { keyword: /[-a-z0-9\s\%]+/ }
  get "svg-sprite/picker-search" => "svg_sprite#icon_picker_search", defaults: { format: :json }
  get "svg-sprite/:hostname/icon(/:color)/:name.svg" => "svg_sprite#svg_icon", constraints: { hostname: /[\w\.-]+/, name: /[-a-z0-9\s\%]+/, color: /(\h{3}{1,2})/, format: :svg }

  get "highlight-js/:hostname/:version.js" => "highlight_js#show", constraints: { hostname: /[\w\.-]+/, format: :js }

  get "stylesheets/:name.css.map" => "stylesheets#show_source_map", constraints: { name: /[-a-z0-9_]+/ }
  get "stylesheets/:name.css" => "stylesheets#show", constraints: { name: /[-a-z0-9_]+/ }
  get "theme-javascripts/:digest.js" => "theme_javascripts#show", constraints: { digest: /\h{40}/ }

  post "uploads/lookup-metadata" => "uploads#metadata"
  post "uploads" => "uploads#create"
  post "uploads/lookup-urls" => "uploads#lookup_urls"

  # used to download original images
  get "uploads/:site/:sha(.:extension)" => "uploads#show", constraints: { site: /\w+/, sha: /\h{40}/, extension: /[a-z0-9\._]+/i }
  get "uploads/short-url/:base62(.:extension)" => "uploads#show_short", constraints: { site: /\w+/, base62: /[a-zA-Z0-9]+/, extension: /[a-z0-9\._]+/i }, as: :upload_short
  # used to download attachments
  get "uploads/:site/original/:tree:sha(.:extension)" => "uploads#show", constraints: { site: /\w+/, tree: /([a-z0-9]+\/)+/i, sha: /\h{40}/, extension: /[a-z0-9\._]+/i }
  if Rails.env.test?
    get "uploads/:site/test_:index/original/:tree:sha(.:extension)" => "uploads#show", constraints: { site: /\w+/, index: /\d+/, tree: /([a-z0-9]+\/)+/i, sha: /\h{40}/, extension: /[a-z0-9\._]+/i }
  end
  # used to download attachments (old route)
  get "uploads/:site/:id/:sha" => "uploads#show", constraints: { site: /\w+/, id: /\d+/, sha: /\h{16}/, format: /.*/ }
  get "secure-media-uploads/*path(.:extension)" => "uploads#show_secure", constraints: { extension: /[a-z0-9\._]+/i }

  get "posts" => "posts#latest", id: "latest_posts", constraints: { format: /(json|rss)/ }
  get "private-posts" => "posts#latest", id: "private_posts", constraints: { format: /(json|rss)/ }
  get "posts/by_number/:topic_id/:post_number" => "posts#by_number"
  get "posts/by-date/:topic_id/:date" => "posts#by_date"
  get "posts/:id/reply-history" => "posts#reply_history"
  get "posts/:id/reply-ids"     => "posts#reply_ids"
  get "posts/:id/reply-ids/all" => "posts#all_reply_ids"
  get "posts/:username/deleted" => "posts#deleted_posts", constraints: { username: RouteFormat.username }
  get "posts/:username/flagged" => "posts#flagged_posts", constraints: { username: RouteFormat.username }

  %w{groups g}.each do |root_path|
    resources :groups, id: RouteFormat.username, path: root_path do
      get "posts.rss" => "groups#posts_feed", format: :rss
      get "mentions.rss" => "groups#mentions_feed", format: :rss

      get 'members'
      get 'posts'
      get 'mentions'
      get 'counts'
      get 'mentionable'
      get 'messageable'
      get 'logs' => 'groups#histories'

      collection do
        get "check-name" => 'groups#check_name'
        get 'custom/new' => 'groups#new', constraints: AdminConstraint.new
        get "search" => "groups#search"
      end

      member do
        %w{
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
          manage/logs
        }.each do |path|
          get path => 'groups#show'
        end

        put "members" => "groups#add_members"
        delete "members" => "groups#remove_member"
        post "request_membership" => "groups#request_membership"
        put "handle_membership_request" => "groups#handle_membership_request"
        post "notifications" => "groups#set_notifications"
      end
    end
  end

  # aliases so old API code works
  delete "admin/groups/:id/members" => "groups#remove_member", constraints: AdminConstraint.new
  put "admin/groups/:id/members" => "groups#add_members", constraints: AdminConstraint.new

  resources :posts do
    delete "bookmark", to: "posts#destroy_bookmark"
    put "wiki"
    put "post_type"
    put "rebake"
    put "unhide"
    put "locked"
    put "notice"
    get "replies"
    get "revisions/latest" => "posts#latest_revision"
    get "revisions/:revision" => "posts#revisions", constraints: { revision: /\d+/ }
    put "revisions/:revision/hide" => "posts#hide_revision", constraints: { revision: /\d+/ }
    put "revisions/:revision/show" => "posts#show_revision", constraints: { revision: /\d+/ }
    put "revisions/:revision/revert" => "posts#revert", constraints: { revision: /\d+/ }
    put "recover"
    collection do
      delete "destroy_many"
      put "merge_posts"
    end
  end

  resources :bookmarks, only: %i[create destroy update]

  resources :notifications, except: :show do
    collection do
      put 'mark-read' => 'notifications#mark_read'
      # creating an alias cause the api was extended to mark a single notification
      # this allows us to cleanly target it
      put 'read' => 'notifications#mark_read'
    end
  end

  match "/auth/failure", to: "users/omniauth_callbacks#failure", via: [:get, :post]
  get "/auth/:provider", to: "users/omniauth_callbacks#confirm_request"
  match "/auth/:provider/callback", to: "users/omniauth_callbacks#complete", via: [:get, :post]
  get "/associate/:token", to: "users/associate_accounts#connect_info", constraints: { token: /\h{32}/ }
  post "/associate/:token", to: "users/associate_accounts#connect", constraints: { token: /\h{32}/ }

  resources :clicks do
    collection do
      post "track"
    end
  end

  get "excerpt" => "excerpt#show"

  resources :post_action_users
  resources :post_readers, only: %i[index]
  resources :post_actions do
    collection do
      get "users"
      post "defer_flags"
    end
  end
  resources :user_actions

  resources :badges, only: [:index]
  get "/badges/:id(/:slug)" => "badges#show", constraints: { format: /(json|html|rss)/ }
  resources :user_badges, only: [:index, :create, :destroy]

  get '/c', to: redirect(relative_url_root + 'categories')

  resources :categories, except: [:show, :new, :edit]
  post "categories/reorder" => "categories#reorder"

  scope path: 'category/:category_id' do
    post "/move" => "categories#move"
    post "/notifications" => "categories#set_notifications"
    put "/slug" => "categories#update_slug"
  end

  get "category/*path" => "categories#redirect"

  get "categories_and_latest" => "categories#categories_and_latest"
  get "categories_and_top" => "categories#categories_and_top"

  get "c/:id/show" => "categories#show"

  get "c/:category_slug/find_by_slug" => "categories#find_by_slug"
  get "c/:parent_category_slug/:category_slug/find_by_slug" => "categories#find_by_slug"

  get "c/*category_slug_path_with_id.rss" => "list#category_feed", format: :rss
  scope path: 'c/*category_slug_path_with_id' do
    get "/none" => "list#category_none_latest"
    get "/none/l/top" => "list#category_none_top", as: "category_none_top"
    get "/l/top" => "list#category_top", as: "category_top"

    TopTopic.periods.each do |period|
      get "/none/l/top/#{period}" => "list#category_none_top_#{period}", as: "category_none_top_#{period}"
      get "/l/top/#{period}" => "list#category_top_#{period}", as: "category_top_#{period}"
    end

    Discourse.filters.each do |filter|
      get "/none/l/#{filter}" => "list#category_none_#{filter}", as: "category_none_#{filter}"
      get "/l/#{filter}" => "list#category_#{filter}", as: "category_#{filter}"
    end

    get "/" => "list#category_default", as: "category_default"
  end

  get "category_hashtags/check" => "category_hashtags#check"

  TopTopic.periods.each do |period|
    get "top/#{period}.rss" => "list#top_#{period}_feed", format: :rss
    get "top/#{period}" => "list#top_#{period}"
  end

  Discourse.anonymous_filters.each do |filter|
    get "#{filter}.rss" => "list##{filter}_feed", format: :rss
  end

  Discourse.filters.each do |filter|
    get "#{filter}" => "list##{filter}"
  end

  get "top" => "list#top"
  get "search/query" => "search#query"
  get "search" => "search#show"
  post "search/click" => "search#click"

  # Topics resource
  get "t/:id" => "topics#show"
  put "t/:id" => "topics#update"
  delete "t/:id" => "topics#destroy"
  put "t/:id/archive-message" => "topics#archive_message"
  put "t/:id/move-to-inbox" => "topics#move_to_inbox"
  put "t/:id/convert-topic/:type" => "topics#convert_topic"
  put "t/:id/publish" => "topics#publish"
  put "t/:id/shared-draft" => "topics#update_shared_draft"
  put "t/:id/reset-bump-date" => "topics#reset_bump_date"
  put "topics/bulk"
  put "topics/reset-new" => 'topics#reset_new'
  post "topics/timings"

  get 'topics/similar_to' => 'similar_topics#index'
  resources :similar_topics

  get "topics/feature_stats"

  scope "/topics", username: RouteFormat.username do
    get "created-by/:username" => "list#topics_by", as: "topics_by", defaults: { format: :json }
    get "private-messages/:username" => "list#private_messages", as: "topics_private_messages", defaults: { format: :json }
    get "private-messages-sent/:username" => "list#private_messages_sent", as: "topics_private_messages_sent", defaults: { format: :json }
    get "private-messages-archive/:username" => "list#private_messages_archive", as: "topics_private_messages_archive", defaults: { format: :json }
    get "private-messages-unread/:username" => "list#private_messages_unread", as: "topics_private_messages_unread", defaults: { format: :json }
    get "private-messages-tags/:username/:tag_id.json" => "list#private_messages_tag", as: "topics_private_messages_tag", constraints: StaffConstraint.new
    get "groups/:group_name" => "list#group_topics", as: "group_topics", group_name: RouteFormat.username

    scope "/private-messages-group/:username", group_name: RouteFormat.username do
      get ":group_name.json" => "list#private_messages_group", as: "topics_private_messages_group"
      get ":group_name/archive.json" => "list#private_messages_group_archive", as: "topics_private_messages_group_archive"
    end
  end

  get 'embed/topics' => 'embed#topics'
  get 'embed/comments' => 'embed#comments'
  get 'embed/count' => 'embed#count'
  get 'embed/info' => 'embed#info'

  get "new-topic" => "list#latest"
  get "new-message" => "list#latest"

  # Topic routes
  get "t/id_for/:slug" => "topics#id_for_slug"
  get "t/:slug/:topic_id/print" => "topics#show", format: :html, print: true, constraints: { topic_id: /\d+/ }
  get "t/:slug/:topic_id/wordpress" => "topics#wordpress", constraints: { topic_id: /\d+/ }
  get "t/:topic_id/wordpress" => "topics#wordpress", constraints: { topic_id: /\d+/ }
  get "t/:slug/:topic_id/moderator-liked" => "topics#moderator_liked", constraints: { topic_id: /\d+/ }
  get "t/:slug/:topic_id/summary" => "topics#show", defaults: { summary: true }, constraints: { topic_id: /\d+/ }
  get "t/:topic_id/summary" => "topics#show", constraints: { topic_id: /\d+/ }
  put "t/:slug/:topic_id" => "topics#update", constraints: { topic_id: /\d+/ }
  put "t/:slug/:topic_id/star" => "topics#star", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/star" => "topics#star", constraints: { topic_id: /\d+/ }
  put "t/:slug/:topic_id/status" => "topics#status", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/status" => "topics#status", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/clear-pin" => "topics#clear_pin", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/re-pin" => "topics#re_pin", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/mute" => "topics#mute", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/unmute" => "topics#unmute", constraints: { topic_id: /\d+/ }
  post "t/:topic_id/timer" => "topics#timer", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/make-banner" => "topics#make_banner", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/remove-banner" => "topics#remove_banner", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/remove-allowed-user" => "topics#remove_allowed_user", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/remove-allowed-group" => "topics#remove_allowed_group", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/recover" => "topics#recover", constraints: { topic_id: /\d+/ }
  get "t/:topic_id/:post_number" => "topics#show", constraints: { topic_id: /\d+/, post_number: /\d+/ }
  get "t/:topic_id/last" => "topics#show", post_number: 99999999, constraints: { topic_id: /\d+/ }
  get "t/:slug/:topic_id.rss" => "topics#feed", format: :rss, constraints: { topic_id: /\d+/ }
  get "t/:slug/:topic_id" => "topics#show", constraints: { topic_id: /\d+/ }
  get "t/:slug/:topic_id/:post_number" => "topics#show", constraints: { topic_id: /\d+/, post_number: /\d+/ }
  get "t/:slug/:topic_id/last" => "topics#show", post_number: 99999999, constraints: { topic_id: /\d+/ }
  get "t/:topic_id/posts" => "topics#posts", constraints: { topic_id: /\d+/ }, format: :json
  get "t/:topic_id/post_ids" => "topics#post_ids", constraints: { topic_id: /\d+/ }, format: :json
  get "t/:topic_id/excerpts" => "topics#excerpts", constraints: { topic_id: /\d+/ }, format: :json
  post "t/:topic_id/timings" => "topics#timings", constraints: { topic_id: /\d+/ }
  post "t/:topic_id/invite" => "topics#invite", constraints: { topic_id: /\d+/ }
  post "t/:topic_id/invite-group" => "topics#invite_group", constraints: { topic_id: /\d+/ }
  post "t/:topic_id/move-posts" => "topics#move_posts", constraints: { topic_id: /\d+/ }
  post "t/:topic_id/merge-topic" => "topics#merge_topic", constraints: { topic_id: /\d+/ }
  post "t/:topic_id/change-owner" => "topics#change_post_owners", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/change-timestamp" => "topics#change_timestamps", constraints: { topic_id: /\d+/ }
  delete "t/:topic_id/timings" => "topics#destroy_timings", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/bookmark" => "topics#bookmark", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/remove_bookmarks" => "topics#remove_bookmarks", constraints: { topic_id: /\d+/ }
  put "t/:topic_id/tags" => "topics#update_tags", constraints: { topic_id: /\d+/ }

  post "t/:topic_id/notifications" => "topics#set_notifications" , constraints: { topic_id: /\d+/ }

  get "p/:post_id(/:user_id)" => "posts#short_link"
  get "/posts/:id/cooked" => "posts#cooked"
  get "/posts/:id/expand-embed" => "posts#expand_embed"
  get "/posts/:id/raw" => "posts#markdown_id"
  get "/posts/:id/raw-email" => "posts#raw_email"
  get "raw/:topic_id(/:post_number)" => "posts#markdown_num"

  resources :invites, except: [:show]
  get "/invites/:id" => "invites#show", constraints: { format: :html }

  post "invites/upload_csv" => "invites#upload_csv"
  post "invites/rescind-all" => "invites#rescind_all_invites"
  post "invites/reinvite" => "invites#resend_invite"
  post "invites/reinvite-all" => "invites#resend_all_invites"
  post "invites/link" => "invites#create_invite_link"
  delete "invites" => "invites#destroy"
  put "invites/show/:id" => "invites#perform_accept_invitation", as: 'perform_accept_invite'

  resources :export_csv do
    collection do
      post "export_entity" => "export_csv#export_entity"
    end
  end

  get "onebox" => "onebox#show"
  get "inline-onebox" => "inline_onebox#show"

  get "exception" => "list#latest"

  get "message-bus/poll" => "message_bus#poll"

  resources :drafts, only: [:index]
  get "draft" => "draft#show"
  post "draft" => "draft#update"
  delete "draft" => "draft#destroy"

  if service_worker_asset = Rails.application.assets_manifest.assets['service-worker.js']
    # https://developers.google.com/web/fundamentals/codelabs/debugging-service-workers/
    # Normally the browser will wait until a user closes all tabs that contain the
    # current site before updating to a new Service Worker.
    # Support the old Service Worker path to avoid routing error filling up the
    # logs.
    get "/service-worker.js" => redirect(relative_url_root + service_worker_asset, status: 302), format: :js
    get service_worker_asset => "static#service_worker_asset", format: :js
  elsif Rails.env.development?
    get "/service-worker.js" => "static#service_worker_asset", format: :js
  end

  get "cdn_asset/:site/*path" => "static#cdn_asset", format: false, constraints: { format: /.*/ }
  get "brotli_asset/*path" => "static#brotli_asset", format: false, constraints: { format: /.*/ }

  get "favicon/proxied" => "static#favicon", format: false

  get "robots.txt" => "robots_txt#index"
  get "robots-builder.json" => "robots_txt#builder"
  get "offline.html" => "offline#index"
  get "manifest.webmanifest" => "metadata#manifest", as: :manifest
  get "manifest.json" => "metadata#manifest"
  get ".well-known/assetlinks.json" => "metadata#app_association_android"
  get "apple-app-site-association" => "metadata#app_association_ios", format: false
  get "opensearch" => "metadata#opensearch", constraints: { format: :xml }

  scope '/tag/:tag_id' do
    constraints format: :json do
      get '/' => 'tags#show', as: 'tag_show'
      get '/info' => 'tags#info'
      get '/notifications' => 'tags#notifications'
      put '/notifications' => 'tags#update_notifications'
      put '/' => 'tags#update'
      delete '/' => 'tags#destroy'
      post '/synonyms' => 'tags#create_synonyms'
      delete '/synonyms/:synonym_id' => 'tags#destroy_synonym'

      Discourse.filters.each do |filter|
        get "/l/#{filter}" => "tags#show_#{filter}", as: "tag_show_#{filter}"
      end
    end

    constraints format: :rss do
      get '/' => 'tags#tag_feed'
    end
  end

  scope "/tags" do
    get '/' => 'tags#index'
    get '/filter/list' => 'tags#index'
    get '/filter/search' => 'tags#search'
    get '/check' => 'tags#check_hashtag'
    get '/personal_messages/:username' => 'tags#personal_messages'
    post '/upload' => 'tags#upload'
    get '/unused' => 'tags#list_unused'
    delete '/unused' => 'tags#destroy_unused'

    constraints(tag_id: /[^\/]+?/, format: /json|rss/) do
      scope path: '/c/*category_slug_path_with_id' do
        Discourse.filters.each do |filter|
          get "/none/:tag_id/l/#{filter}" => "tags#show_#{filter}", as: "tag_category_none_show_#{filter}", defaults: { no_subcategories: true }
        end

        get '/none/:tag_id' => 'tags#show', as: 'tag_category_none_show', defaults: { no_subcategories: true }

        Discourse.filters.each do |filter|
          get "/:tag_id/l/#{filter}" => "tags#show_#{filter}", as: "tag_category_show_#{filter}"
        end

        get '/:tag_id' => 'tags#show', as: 'tag_category_show'
      end

      get '/intersection/:tag_id/*additional_tag_ids' => 'tags#show', as: 'tag_intersection'
    end

    # legacy routes
    constraints(tag_id: /[^\/]+?/, format: /json|rss/) do
      get '/:tag_id.rss' => 'tags#tag_feed'
      get '/:tag_id' => 'tags#show'
      get '/:tag_id/info' => 'tags#info'
      get '/:tag_id/notifications' => 'tags#notifications'
      put '/:tag_id/notifications' => 'tags#update_notifications'
      put '/:tag_id' => 'tags#update'
      delete '/:tag_id' => 'tags#destroy'
      post '/:tag_id/synonyms' => 'tags#create_synonyms'
      delete '/:tag_id/synonyms/:synonym_id' => 'tags#destroy_synonym'

      Discourse.filters.each do |filter|
        get "/:tag_id/l/#{filter}" => "tags#show_#{filter}"
      end
    end
  end

  resources :tag_groups, constraints: StaffConstraint.new, except: [:edit] do
    collection do
      get '/filter/search' => 'tag_groups#search'
    end
  end

  Discourse.filters.each do |filter|
    root to: "list##{filter}", constraints: HomePageConstraint.new("#{filter}"), as: "list_#{filter}"
  end
  # special case for categories
  root to: "categories#index", constraints: HomePageConstraint.new("categories"), as: "categories_index"
  # special case for top
  root to: "list#top", constraints: HomePageConstraint.new("top"), as: "top_lists"

  root to: 'finish_installation#index', constraints: HomePageConstraint.new("finish_installation"), as: 'installation_redirect'

  get "/user-api-key/new" => "user_api_keys#new"
  post "/user-api-key" => "user_api_keys#create"
  post "/user-api-key/revoke" => "user_api_keys#revoke"
  post "/user-api-key/undo-revoke" => "user_api_keys#undo_revoke"
  get "/user-api-key/otp" => "user_api_keys#otp"
  post "/user-api-key/otp" => "user_api_keys#create_otp"

  get "/safe-mode" => "safe_mode#index"
  post "/safe-mode" => "safe_mode#enter", as: "safe_mode_enter"

  get "/themes/assets/:ids" => "themes#assets"

  unless Rails.env.production?
    get "/qunit" => "qunit#index"
    get "/wizard/qunit" => "wizard#qunit"
  end

  post "/push_notifications/subscribe" => "push_notification#subscribe"
  post "/push_notifications/unsubscribe" => "push_notification#unsubscribe"

  resources :csp_reports, only: [:create]

  get "/permalink-check", to: 'permalinks#check'

  get "*url", to: 'permalinks#show', constraints: PermalinkConstraint.new
  end
end
