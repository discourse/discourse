require "sidekiq/web"
require_dependency "scheduler/web"
require_dependency "admin_constraint"
require_dependency "staff_constraint"
require_dependency "homepage_constraint"
require_dependency "permalink_constraint"

# This used to be User#username_format, but that causes a preload of the User object
# and makes Guard not work properly.
USERNAME_ROUTE_FORMAT = /[A-Za-z0-9\_]+/ unless defined? USERNAME_ROUTE_FORMAT
BACKUP_ROUTE_FORMAT = /[a-zA-Z0-9\-_]*\d{4}(-\d{2}){2}-\d{6}\.tar\.gz/i unless defined? BACKUP_ROUTE_FORMAT

Discourse::Application.routes.draw do

  match "/404", to: "exceptions#not_found", via: [:get, :post]
  get "/404-body" => "exceptions#not_found_body"

  if Rails.env.development?
    mount Sidekiq::Web => "/sidekiq"
    mount Logster::Web => "/logs"
  else
    mount Sidekiq::Web => "/sidekiq", constraints: AdminConstraint.new
    mount Logster::Web => "/logs", constraints: AdminConstraint.new
  end

  resources :about

  get "site" => "site#index"

  resources :forums
  get "srv/status" => "forums#status"

  namespace :admin, constraints: StaffConstraint.new do
    get "" => "admin#index"

    resources :site_settings, constraints: AdminConstraint.new do
      collection do
        get "category/:id" => "site_settings#index"
      end
    end

    get "reports/:type" => "reports#show"

    resources :groups, constraints: AdminConstraint.new do
      collection do
        post "refresh_automatic_groups" => "groups#refresh_automatic_groups"
      end
      get "users"
    end

    resources :users, id: USERNAME_ROUTE_FORMAT do
      collection do
        get "list/:query" => "users#index"
        get "ip-info" => "users#ip_info"
        put "approve-bulk" => "users#approve_bulk"
        delete "reject-bulk" => "users#reject_bulk"
      end
      put "suspend"
      put "delete_all_posts"
      put "unsuspend"
      put "revoke_admin", constraints: AdminConstraint.new
      put "grant_admin", constraints: AdminConstraint.new
      post "generate_api_key", constraints: AdminConstraint.new
      delete "revoke_api_key", constraints: AdminConstraint.new
      put "revoke_moderation", constraints: AdminConstraint.new
      put "grant_moderation", constraints: AdminConstraint.new
      put "approve"
      post "refresh_browsers", constraints: AdminConstraint.new
      post "log_out", constraints: AdminConstraint.new
      put "activate"
      put "deactivate"
      put "block"
      put "unblock"
      put "trust_level"
      put "trust_level_lock"
      put "primary_group"
      post "groups" => "users#add_group", constraints: AdminConstraint.new
      delete "groups/:group_id" => "users#remove_group", constraints: AdminConstraint.new
      get "badges"
      get "leader_requirements" => "users#tl3_requirements"
      get "tl3_requirements"
    end


    post "users/sync_sso" => "users#sync_sso", constraints: AdminConstraint.new

    resources :impersonate, constraints: AdminConstraint.new

    resources :email do
      collection do
        post "test"
        get "all"
        get "sent"
        get "skipped"
        get "preview-digest" => "email#preview_digest"
      end
    end

    scope "/logs" do
      resources :staff_action_logs,     only: [:index]
      resources :screened_emails,       only: [:index, :destroy]
      resources :screened_ip_addresses, only: [:index, :create, :update, :destroy]
      resources :screened_urls,         only: [:index]
    end

    get "/logs" => "staff_action_logs#index"

    get "customize" => "color_schemes#index", constraints: AdminConstraint.new
    get "customize/css_html" => "site_customizations#index", constraints: AdminConstraint.new
    get "customize/colors" => "color_schemes#index", constraints: AdminConstraint.new
    get "flags" => "flags#index"
    get "flags/:filter" => "flags#index"
    post "flags/agree/:id" => "flags#agree"
    post "flags/disagree/:id" => "flags#disagree"
    post "flags/defer/:id" => "flags#defer"
    resources :site_customizations, constraints: AdminConstraint.new
    scope "/customize" do
      resources :site_text, constraints: AdminConstraint.new
      resources :site_text_types, constraints: AdminConstraint.new
      resources :user_fields, constraints: AdminConstraint.new
    end

    resources :color_schemes, constraints: AdminConstraint.new

    get "version_check" => "versions#show"

    resources :dashboard, only: [:index] do
      collection do
        get "problems"
      end
    end

    resources :api, only: [:index], constraints: AdminConstraint.new do
      collection do
        post "key" => "api#create_master_key"
        put "key" => "api#regenerate_key"
        delete "key" => "api#revoke_key"
      end
    end

    resources :backups, only: [:index, :create], constraints: AdminConstraint.new do
      member do
        get "" => "backups#show", constraints: { id: BACKUP_ROUTE_FORMAT }
        delete "" => "backups#destroy", constraints: { id: BACKUP_ROUTE_FORMAT }
        post "restore" => "backups#restore", constraints: { id: BACKUP_ROUTE_FORMAT }
      end
      collection do
        get "logs" => "backups#logs"
        get "status" => "backups#status"
        get "cancel" => "backups#cancel"
        get "rollback" => "backups#rollback"
        put "readonly" => "backups#readonly"
        get "upload" => "backups#check_backup_chunk"
        post "upload" => "backups#upload_backup_chunk"
      end
    end

    resources :export_csv, constraints: AdminConstraint.new do
      member do
        get "download" => "export_csv#download", constraints: { id: /[^\/]+/ }
      end
      collection do
        get "users" => "export_csv#export_user_list"
      end
    end

    resources :badges, constraints: AdminConstraint.new do
      collection do
        get "types" => "badges#badge_types"
        post "badge_groupings" => "badges#save_badge_groupings"
        post "preview" => "badges#preview"
      end
    end

    get "memory_stats"=> "diagnostics#memory_stats", constraints: AdminConstraint.new

  end # admin namespace

  get "email_preferences" => "email#preferences_redirect", :as => "email_preferences_redirect"
  get "email/unsubscribe/:key" => "email#unsubscribe", as: "email_unsubscribe"
  post "email/resubscribe/:key" => "email#resubscribe", as: "email_resubscribe"

  resources :session, id: USERNAME_ROUTE_FORMAT, only: [:create, :destroy, :become] do
    get 'become'
    collection do
      post "forgot_password"
    end
  end

  get "session/sso" => "session#sso"
  get "session/sso_login" => "session#sso_login"
  get "session/current" => "session#current"
  get "session/csrf" => "session#csrf"
  get "composer-messages" => "composer_messages#index"

  resources :users, except: [:show, :update, :destroy] do
    collection do
      get "check_username"
      get "is_local_username"
    end
  end

  resources :static
  post "login" => "static#enter"
  get "login" => "static#show", id: "login"
  get "faq" => "static#show", id: "faq"
  get "guidelines" => "static#show", id: "guidelines"
  get "tos" => "static#show", id: "tos"
  get "privacy" => "static#show", id: "privacy"
  get "signup" => "list#latest"

  post "users/read-faq" => "users#read_faq"
  get "users/search/users" => "users#search_users"
  get "users/account-created/" => "users#account_created"
  get "users/password-reset/:token" => "users#password_reset"
  put "users/password-reset/:token" => "users#password_reset"
  get "users/activate-account/:token" => "users#activate_account"
  put "users/activate-account/:token" => "users#perform_account_activation", as: 'perform_activate_account'
  get "users/authorize-email/:token" => "users#authorize_email"
  get "users/hp" => "users#get_honeypot_value"
  get "my/*path", to: 'users#my_redirect'

  get "user_preferences" => "users#user_preferences_redirect"
  get "users/:username/private-messages" => "user_actions#private_messages", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/private-messages/:filter" => "user_actions#private_messages", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username" => "users#show", as: 'user', constraints: {username: USERNAME_ROUTE_FORMAT}
  put "users/:username" => "users#update", constraints: {username: USERNAME_ROUTE_FORMAT}
  put "users/:username/emails" => "users#check_emails", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/preferences" => "users#preferences", constraints: {username: USERNAME_ROUTE_FORMAT}, as: :email_preferences
  get "users/:username/preferences/email" => "users#preferences", constraints: {username: USERNAME_ROUTE_FORMAT}
  put "users/:username/preferences/email" => "users#change_email", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/preferences/about-me" => "users#preferences", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/preferences/badge_title" => "users#preferences", constraints: {username: USERNAME_ROUTE_FORMAT}
  put "users/:username/preferences/badge_title" => "users#badge_title", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/preferences/username" => "users#preferences", constraints: {username: USERNAME_ROUTE_FORMAT}
  put "users/:username/preferences/username" => "users#username", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/avatar(/:size)" => "users#avatar", constraints: {username: USERNAME_ROUTE_FORMAT} # LEGACY ROUTE
  post "users/:username/preferences/avatar" => "users#upload_avatar", constraints: {username: USERNAME_ROUTE_FORMAT} # LEGACY ROUTE
  post "users/:username/preferences/user_image" => "users#upload_user_image", constraints: {username: USERNAME_ROUTE_FORMAT}
  delete "users/:username/preferences/user_image" => "users#destroy_user_image", constraints: {username: USERNAME_ROUTE_FORMAT}
  put "users/:username/preferences/avatar/pick" => "users#pick_avatar", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/preferences/card-badge" => "users#card_badge", constraints: {username: USERNAME_ROUTE_FORMAT}
  put "users/:username/preferences/card-badge" => "users#update_card_badge", constraints: {username: USERNAME_ROUTE_FORMAT}


  get "users/:username/invited" => "users#invited", constraints: {username: USERNAME_ROUTE_FORMAT}
  post "users/action/send_activation_email" => "users#send_activation_email"
  get "users/:username/activity" => "users#show", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/activity/:filter" => "users#show", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/badges" => "users#show", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/notifications" => "users#show", constraints: {username: USERNAME_ROUTE_FORMAT}
  delete "users/:username" => "users#destroy", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/by-external/:external_id" => "users#show"
  get "users/:username/flagged-posts" => "users#show", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/deleted-posts" => "users#show", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "users/:username/badges_json" => "user_badges#username"

  post "user_avatar/:username/refresh_gravatar" => "user_avatars#refresh_gravatar"
  get "letter_avatar/:username/:size/:version.png" => "user_avatars#show_letter", format: false, constraints: { hostname: /[\w\.-]+/ }
  get "user_avatar/:hostname/:username/:size/:version.png" => "user_avatars#show", format: false, constraints: { hostname: /[\w\.-]+/ }

  get "uploads/:site/:id/:sha.:extension" => "uploads#show", constraints: {site: /\w+/, id: /\d+/, sha: /[a-z0-9]{15,16}/i, extension: /\w{2,}/}
  get "uploads/:site/:sha" => "uploads#show", constraints: { site: /\w+/, sha: /[a-z0-9]{40}/}
  post "uploads" => "uploads#create"

  get "posts/by_number/:topic_id/:post_number" => "posts#by_number"
  get "posts/:id/reply-history" => "posts#reply_history"
  get "posts/:username/deleted" => "posts#deleted_posts", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "posts/:username/flagged" => "posts#flagged_posts", constraints: {username: USERNAME_ROUTE_FORMAT}

  resources :groups do
    get 'members'
    get 'posts'
    get 'counts'
  end

  # In case people try the wrong URL
  get '/group/:id', to: redirect('/groups/%{id}')
  get '/group/:id/members', to: redirect('/groups/%{id}/members')

  resources :posts do
    put "bookmark"
    put "wiki"
    put "post_type"
    put "rebake"
    put "unhide"
    get "replies"
    get "revisions/latest" => "posts#latest_revision"
    get "revisions/:revision" => "posts#revisions", constraints: { revision: /\d+/ }
    put "revisions/:revision/hide" => "posts#hide_revision", constraints: { revision: /\d+/ }
    put "revisions/:revision/show" => "posts#show_revision", constraints: { revision: /\d+/ }
    put "recover"
    collection do
      delete "destroy_many"
    end
  end

  get "notifications" => "notifications#recent"
  get "notifications/history" => "notifications#history"
  put "notifications/reset-new" => 'notifications#reset_new'

  match "/auth/:provider/callback", to: "users/omniauth_callbacks#complete", via: [:get, :post]
  match "/auth/failure", to: "users/omniauth_callbacks#failure", via: [:get, :post]

  resources :clicks do
    collection do
      get "track"
    end
  end

  get "excerpt" => "excerpt#show"

  resources :post_actions do
    collection do
      get "users"
      post "defer_flags"
    end
  end
  resources :user_actions

  resources :badges, only: [:index]
  get "/badges/:id(/:slug)" => "badges#show"
  resources :user_badges, only: [:index, :create, :destroy]

  # We've renamed popular to latest. If people access it we want a permanent redirect.
  get "popular" => "list#popular_redirect"

  resources :categories, :except => :show
  post "category/uploads" => "categories#upload"
  post "category/:category_id/move" => "categories#move"
  post "category/:category_id/notifications" => "categories#set_notifications"

  get "c/:id/show" => "categories#show"
  get "c/:category.rss" => "list#category_feed", format: :rss
  get "c/:parent_category/:category.rss" => "list#category_feed", format: :rss
  get "c/:category" => "list#category_latest"
  get "c/:category/none" => "list#category_none_latest"
  get "c/:parent_category/:category" => "list#parent_category_category_latest"
  get "c/:category/l/top" => "list#category_top", as: "category_top"
  get "c/:category/none/l/top" => "list#category_none_top", as: "category_none_top"
  get "c/:parent_category/:category/l/top" => "list#parent_category_category_top", as: "parent_category_category_top"


  TopTopic.periods.each do |period|
    get "top/#{period}" => "list#top_#{period}"
    get "c/:category/l/top/#{period}" => "list#category_top_#{period}", as: "category_top_#{period}"
    get "c/:category/none/l/top/#{period}" => "list#category_none_top_#{period}", as: "category_none_top_#{period}"
    get "c/:parent_category/:category/l/top/#{period}" => "list#parent_category_category_top_#{period}", as: "parent_category_category_top_#{period}"
  end

  Discourse.anonymous_filters.each do |filter|
    get "#{filter}.rss" => "list##{filter}_feed", format: :rss
  end

  Discourse.filters.each do |filter|
    get "#{filter}" => "list##{filter}"
    get "c/:category/l/#{filter}" => "list#category_#{filter}", as: "category_#{filter}"
    get "c/:category/none/l/#{filter}" => "list#category_none_#{filter}", as: "category_none_#{filter}"
    get "c/:parent_category/:category/l/#{filter}" => "list#parent_category_category_#{filter}", as: "parent_category_category_#{filter}"
  end

  get "category/*path" => "categories#redirect"

  get "top" => "list#top"
  get "search" => "search#query"

  # Topics resource
  get "t/:id" => "topics#show"
  post "t" => "topics#create"
  put "t/:id" => "topics#update"
  delete "t/:id" => "topics#destroy"
  put "topics/bulk"
  put "topics/reset-new" => 'topics#reset_new'
  post "topics/timings"
  get "topics/similar_to"
  get "topics/created-by/:username" => "list#topics_by", as: "topics_by", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "topics/private-messages/:username" => "list#private_messages", as: "topics_private_messages", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "topics/private-messages-sent/:username" => "list#private_messages_sent", as: "topics_private_messages_sent", constraints: {username: USERNAME_ROUTE_FORMAT}
  get "topics/private-messages-unread/:username" => "list#private_messages_unread", as: "topics_private_messages_unread", constraints: {username: USERNAME_ROUTE_FORMAT}

  get 'embed/comments' => 'embed#comments'
  get 'embed/count' => 'embed#count'

  # Topic routes
  get "t/id_for/:slug" => "topics#id_for_slug"
  get "t/:slug/:topic_id/wordpress" => "topics#wordpress", constraints: {topic_id: /\d+/}
  get "t/:slug/:topic_id/moderator-liked" => "topics#moderator_liked", constraints: {topic_id: /\d+/}
  get "t/:topic_id/wordpress" => "topics#wordpress", constraints: {topic_id: /\d+/}
  get "t/:slug/:topic_id/summary" => "topics#show", defaults: {summary: true}, constraints: {topic_id: /\d+/, post_number: /\d+/}
  get "t/:topic_id/summary" => "topics#show", constraints: {topic_id: /\d+/, post_number: /\d+/}
  put "t/:slug/:topic_id" => "topics#update", constraints: {topic_id: /\d+/}
  put "t/:slug/:topic_id/star" => "topics#star", constraints: {topic_id: /\d+/}
  put "t/:topic_id/star" => "topics#star", constraints: {topic_id: /\d+/}
  put "t/:slug/:topic_id/status" => "topics#status", constraints: {topic_id: /\d+/}
  put "t/:topic_id/status" => "topics#status", constraints: {topic_id: /\d+/}
  put "t/:topic_id/clear-pin" => "topics#clear_pin", constraints: {topic_id: /\d+/}
  put "t/:topic_id/re-pin" => "topics#re_pin", constraints: {topic_id: /\d+/}
  put "t/:topic_id/mute" => "topics#mute", constraints: {topic_id: /\d+/}
  put "t/:topic_id/unmute" => "topics#unmute", constraints: {topic_id: /\d+/}
  put "t/:topic_id/autoclose" => "topics#autoclose", constraints: {topic_id: /\d+/}
  put "t/:topic_id/make-banner" => "topics#make_banner", constraints: {topic_id: /\d+/}
  put "t/:topic_id/remove-banner" => "topics#remove_banner", constraints: {topic_id: /\d+/}
  put "t/:topic_id/remove-allowed-user" => "topics#remove_allowed_user", constraints: {topic_id: /\d+/}
  put "t/:topic_id/recover" => "topics#recover", constraints: {topic_id: /\d+/}
  get "t/:topic_id/:post_number" => "topics#show", constraints: {topic_id: /\d+/, post_number: /\d+/}
  get "t/:topic_id/last" => "topics#show", post_number: 99999999, constraints: {topic_id: /\d+/}
  get "t/:slug/:topic_id.rss" => "topics#feed", format: :rss, constraints: {topic_id: /\d+/}
  get "t/:slug/:topic_id" => "topics#show", constraints: {topic_id: /\d+/}
  get "t/:slug/:topic_id/:post_number" => "topics#show", constraints: {topic_id: /\d+/, post_number: /\d+/}
  get "t/:slug/:topic_id/last" => "topics#show", post_number: 99999999, constraints: {topic_id: /\d+/}
  get "t/:topic_id/posts" => "topics#posts", constraints: {topic_id: /\d+/}
  post "t/:topic_id/timings" => "topics#timings", constraints: {topic_id: /\d+/}
  post "t/:topic_id/invite" => "topics#invite", constraints: {topic_id: /\d+/}
  post "t/:topic_id/move-posts" => "topics#move_posts", constraints: {topic_id: /\d+/}
  post "t/:topic_id/merge-topic" => "topics#merge_topic", constraints: {topic_id: /\d+/}
  post "t/:topic_id/change-owner" => "topics#change_post_owners", constraints: {topic_id: /\d+/}
  delete "t/:topic_id/timings" => "topics#destroy_timings", constraints: {topic_id: /\d+/}

  post "t/:topic_id/notifications" => "topics#set_notifications" , constraints: {topic_id: /\d+/}

  get "p/:post_id(/:user_id)" => "posts#short_link"
  get "/posts/:id/cooked" => "posts#cooked"
  get "/posts/:id/expand-embed" => "posts#expand_embed"
  get "/posts/:id/raw" => "posts#markdown_id"
  get "/posts/:id/raw-email" => "posts#raw_email"
  get "raw/:topic_id(/:post_number)" => "posts#markdown_num"

  resources :invites do
    collection do
      get "upload" => "invites#check_csv_chunk"
      post "upload" => "invites#upload_csv_chunk"
    end
  end
  post "invites/reinvite" => "invites#resend_invite"
  post "invites/disposable" => "invites#create_disposable_invite"
  get "invites/redeem/:token" => "invites#redeem_disposable_invite"
  delete "invites" => "invites#destroy"

  get "onebox" => "onebox#show"

  get "error" => "forums#error"
  get "exception" => "list#latest"

  get "message-bus/poll" => "message_bus#poll"

  get "draft" => "draft#show"
  post "draft" => "draft#update"
  delete "draft" => "draft#destroy"

  get "cdn_asset/:site/*path" => "static#cdn_asset", format: false

  get "robots.txt" => "robots_txt#index"

  Discourse.filters.each do |filter|
    root to: "list##{filter}", constraints: HomePageConstraint.new("#{filter}"), :as => "list_#{filter}"
  end
  # special case for categories
  root to: "categories#index", constraints: HomePageConstraint.new("categories"), :as => "categories_index"
  # special case for top
  root to: "list#top", constraints: HomePageConstraint.new("top"), :as => "top_lists"

  get "*url", to: 'permalinks#show', constraints: PermalinkConstraint.new
end
