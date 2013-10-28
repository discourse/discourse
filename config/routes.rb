require 'sidekiq/web'
require 'sidetiq/web'

require_dependency 'admin_constraint'
require_dependency 'staff_constraint'
require_dependency 'homepage_constraint'

# This used to be User#username_format, but that causes a preload of the User object
# and makes Guard not work properly.
USERNAME_ROUTE_FORMAT = /[A-Za-z0-9\_]+/ unless defined? USERNAME_ROUTE_FORMAT

Discourse::Application.routes.draw do

  match "/404", to: "exceptions#not_found", via: [:get, :post]

  mount Sidekiq::Web => '/sidekiq', constraints: AdminConstraint.new

  resources :forums
  get 'srv/status' => 'forums#status'

  namespace :admin, constraints: StaffConstraint.new do
    get '' => 'admin#index'

    resources :site_settings, constraints: AdminConstraint.new

    get 'reports/:type' => 'reports#show'

    resources :groups, constraints: AdminConstraint.new do
      collection do
        post 'refresh_automatic_groups' => 'groups#refresh_automatic_groups'
      end
      get 'users'
    end

    resources :users, id: USERNAME_ROUTE_FORMAT do
      collection do
        get 'list/:query' => 'users#index'
        put 'approve-bulk' => 'users#approve_bulk'
        delete 'reject-bulk' => 'users#reject_bulk'
      end
      put 'ban'
      put 'delete_all_posts'
      put 'unban'
      put 'revoke_admin', constraints: AdminConstraint.new
      put 'grant_admin', constraints: AdminConstraint.new
      post 'generate_api_key', constraints: AdminConstraint.new
      delete 'revoke_api_key', constraints: AdminConstraint.new
      put 'revoke_moderation', constraints: AdminConstraint.new
      put 'grant_moderation', constraints: AdminConstraint.new
      put 'approve'
      post 'refresh_browsers', constraints: AdminConstraint.new
      put 'activate'
      put 'deactivate'
      put 'block'
      put 'unblock'
      put 'trust_level'
    end

    resources :impersonate, constraints: AdminConstraint.new

    resources :email do
      collection do
        post 'test'
        get 'logs'
        get 'preview-digest' => 'email#preview_digest'
      end
    end

    scope '/logs' do
      resources :staff_action_logs,     only: [:index]
      resources :screened_emails,       only: [:index]
      resources :screened_ip_addresses, only: [:index, :create, :update, :destroy]
      resources :screened_urls,         only: [:index]
    end

    get 'customize' => 'site_customizations#index', constraints: AdminConstraint.new
    get 'flags' => 'flags#index'
    get 'flags/:filter' => 'flags#index'
    post 'flags/agree/:id' => 'flags#agree'
    post 'flags/disagree/:id' => 'flags#disagree'
    post 'flags/defer/:id' => 'flags#defer'
    resources :site_customizations, constraints: AdminConstraint.new
    resources :site_contents, constraints: AdminConstraint.new
    resources :site_content_types, constraints: AdminConstraint.new
    resources :export, constraints: AdminConstraint.new
    get 'version_check' => 'versions#show'
    resources :dashboard, only: [:index] do
      collection do
        get 'problems'
      end
    end
    resources :api, only: [:index], constraints: AdminConstraint.new do
      collection do
        post 'key' => 'api#create_master_key'
        put 'key' => 'api#regenerate_key'
        delete 'key' => 'api#revoke_key'
      end
    end
  end

  get 'email_preferences' => 'email#preferences_redirect', :as => 'email_preferences_redirect'
  get 'email/unsubscribe/:key' => 'email#unsubscribe', as: 'email_unsubscribe'
  post 'email/resubscribe/:key' => 'email#resubscribe', as: 'email_resubscribe'


  resources :session, id: USERNAME_ROUTE_FORMAT, only: [:create, :destroy] do
    collection do
      post 'forgot_password'
    end
  end

  get 'session/csrf' => 'session#csrf'
  get 'composer-messages' => 'composer_messages#index'

  resources :users, except: [:show, :update] do
    collection do
      get 'check_username'
      get 'is_local_username'
    end
  end

  resources :static
  post 'login' => 'static#enter'
  get 'login' => 'static#show', id: 'login'
  get 'faq' => 'static#show', id: 'faq'
  get 'tos' => 'static#show', id: 'tos'
  get 'privacy' => 'static#show', id: 'privacy'

  get 'users/search/users' => 'users#search_users'
  get 'users/password-reset/:token' => 'users#password_reset'
  put 'users/password-reset/:token' => 'users#password_reset'
  get 'users/activate-account/:token' => 'users#activate_account'
  get 'users/authorize-email/:token' => 'users#authorize_email'
  get 'users/hp' => 'users#get_honeypot_value'

  get 'user_preferences' => 'users#user_preferences_redirect'
  get 'users/:username/private-messages' => 'user_actions#private_messages', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/private-messages/:filter' => 'user_actions#private_messages', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username' => 'users#show', constraints: {username: USERNAME_ROUTE_FORMAT}
  put 'users/:username' => 'users#update', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/preferences' => 'users#preferences', constraints: {username: USERNAME_ROUTE_FORMAT}, as: :email_preferences
  get 'users/:username/preferences/email' => 'users#preferences', constraints: {username: USERNAME_ROUTE_FORMAT}
  put 'users/:username/preferences/email' => 'users#change_email', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/preferences/about-me' => 'users#preferences', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/preferences/username' => 'users#preferences', constraints: {username: USERNAME_ROUTE_FORMAT}
  put 'users/:username/preferences/username' => 'users#username', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/avatar(/:size)' => 'users#avatar', constraints: {username: USERNAME_ROUTE_FORMAT} # LEGACY ROUTE
  post 'users/:username/preferences/avatar' => 'users#upload_avatar', constraints: {username: USERNAME_ROUTE_FORMAT}
  put 'users/:username/preferences/avatar/toggle' => 'users#toggle_avatar', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/invited' => 'users#invited', constraints: {username: USERNAME_ROUTE_FORMAT}
  post 'users/:username/send_activation_email' => 'users#send_activation_email', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/activity' => 'users#show', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/activity/:filter' => 'users#show', constraints: {username: USERNAME_ROUTE_FORMAT}

  get 'uploads/:site/:id/:sha.:extension' => 'uploads#show', constraints: {site: /\w+/, id: /\d+/, sha: /[a-z0-9]{15,16}/i, extension: /\w{2,}/}
  post 'uploads' => 'uploads#create'

  get 'posts/by_number/:topic_id/:post_number' => 'posts#by_number'
  get 'posts/:id/reply-history' => 'posts#reply_history'
  resources :posts do
    get 'versions'
    put 'bookmark'
    get 'replies'
    put 'recover'
    collection do
      delete 'destroy_many'
    end
  end

  get 'p/:post_id/:user_id' => 'posts#short_link'

  resources :notifications

  match "/auth/:provider/callback", to: "users/omniauth_callbacks#complete", via: [:get, :post]
  match "/auth/failure", to: "users/omniauth_callbacks#failure", via: [:get, :post]

  resources :clicks do
    collection do
      get 'track'
    end
  end

  get 'excerpt' => 'excerpt#show'

  resources :post_actions do
    collection do
      get 'users'
      post 'clear_flags'
    end
  end
  resources :user_actions

  resources :categories, :except => :show
  get 'category/:id/show' => 'categories#show'
  post 'category/:category_id/move' => 'categories#move', as: 'category_move'

  get 'category/:category.rss' => 'list#category_feed', format: :rss, as: 'category_feed'
  get 'category/:category' => 'list#category', as: 'category_list'
  get 'category/:category/more' => 'list#category', as: 'category_list_more'

  # We've renamed popular to latest. If people access it we want a permanent redirect.
  get 'popular' => 'list#popular_redirect'
  get 'popular/more' => 'list#popular_redirect'

  [:latest, :hot].each do |filter|
    get "#{filter}.rss" => "list##{filter}_feed", format: :rss
  end

  [:latest, :hot, :favorited, :read, :posted, :unread, :new].each do |filter|
    get "#{filter}" => "list##{filter}"
    get "#{filter}/more" => "list##{filter}"

    get "category/:category/l/#{filter}" => "list##{filter}"
    get "category/:category/l/#{filter}/more" => "list##{filter}"
    get "category/:parent_category/:category/l/#{filter}" => "list##{filter}"
    get "category/:parent_category/:category/l/#{filter}/more" => "list##{filter}"
  end

  get 'category/:parent_category/:category' => 'list#category', as: 'category_list_parent'

  get 'search' => 'search#query'

  # Topics resource
  get 't/:id' => 'topics#show'
  delete 't/:id' => 'topics#destroy'
  put 't/:id' => 'topics#update'
  post 't' => 'topics#create'
  post 'topics/timings'
  get 'topics/similar_to'
  get 'topics/created-by/:username' => 'list#topics_by', as: 'topics_by', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'topics/private-messages/:username' => 'list#private_messages', as: 'topics_private_messages', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'topics/private-messages-sent/:username' => 'list#private_messages_sent', as: 'topics_private_messages_sent', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'topics/private-messages-unread/:username' => 'list#private_messages_unread', as: 'topics_private_messages_unread', constraints: {username: USERNAME_ROUTE_FORMAT}

  # Topic routes
  get 't/:slug/:topic_id/wordpress' => 'topics#wordpress', constraints: {topic_id: /\d+/}
  get 't/:slug/:topic_id/moderator-liked' => 'topics#moderator_liked', constraints: {topic_id: /\d+/}
  get 't/:topic_id/wordpress' => 'topics#wordpress', constraints: {topic_id: /\d+/}
  get 't/:slug/:topic_id/best_of' => 'topics#show', defaults: {best_of: true}, constraints: {topic_id: /\d+/, post_number: /\d+/}
  get 't/:topic_id/best_of' => 'topics#show', constraints: {topic_id: /\d+/, post_number: /\d+/}
  put 't/:slug/:topic_id' => 'topics#update', constraints: {topic_id: /\d+/}
  put 't/:slug/:topic_id/star' => 'topics#star', constraints: {topic_id: /\d+/}
  put 't/:topic_id/star' => 'topics#star', constraints: {topic_id: /\d+/}
  put 't/:slug/:topic_id/status' => 'topics#status', constraints: {topic_id: /\d+/}
  put 't/:topic_id/status' => 'topics#status', constraints: {topic_id: /\d+/}
  put 't/:topic_id/clear-pin' => 'topics#clear_pin', constraints: {topic_id: /\d+/}
  put 't/:topic_id/mute' => 'topics#mute', constraints: {topic_id: /\d+/}
  put 't/:topic_id/unmute' => 'topics#unmute', constraints: {topic_id: /\d+/}
  put 't/:topic_id/autoclose' => 'topics#autoclose', constraints: {topic_id: /\d+/}
  put 't/:topic_id/remove-allowed-user' => 'topics#remove_allowed_user', constraints: {topic_id: /\d+/}
  put 't/:topic_id/recover' => 'topics#recover', constraints: {topic_id: /\d+/}
  get 't/:topic_id/:post_number' => 'topics#show', constraints: {topic_id: /\d+/, post_number: /\d+/}
  get 't/:slug/:topic_id.rss' => 'topics#feed', format: :rss, constraints: {topic_id: /\d+/}
  get 't/:slug/:topic_id' => 'topics#show', constraints: {topic_id: /\d+/}
  get 't/:slug/:topic_id/:post_number' => 'topics#show', constraints: {topic_id: /\d+/, post_number: /\d+/}
  get 't/:topic_id/posts' => 'topics#posts', constraints: {topic_id: /\d+/}
  post 't/:topic_id/timings' => 'topics#timings', constraints: {topic_id: /\d+/}
  post 't/:topic_id/invite' => 'topics#invite', constraints: {topic_id: /\d+/}
  post 't/:topic_id/move-posts' => 'topics#move_posts', constraints: {topic_id: /\d+/}
  post 't/:topic_id/merge-topic' => 'topics#merge_topic', constraints: {topic_id: /\d+/}
  delete 't/:topic_id/timings' => 'topics#destroy_timings', constraints: {topic_id: /\d+/}

  post 't/:topic_id/notifications' => 'topics#set_notifications' , constraints: {topic_id: /\d+/}

  get 'raw/:topic_id(/:post_number)' => 'posts#markdown'


  resources :invites
  delete 'invites' => 'invites#destroy'

  get 'onebox' => 'onebox#show'

  get 'error' => 'forums#error'

  get 'message-bus/poll' => 'message_bus#poll'

  get 'draft' => 'draft#show'
  post 'draft' => 'draft#update'
  delete 'draft' => 'draft#destroy'

  get 'robots.txt' => 'robots_txt#index'

  [:latest, :hot, :unread, :new, :favorited, :read, :posted].each do |filter|
    root to: "list##{filter}", constraints: HomePageConstraint.new("#{filter}"), :as => "list_#{filter}"
  end
  # special case for categories
  root to: "categories#index", constraints: HomePageConstraint.new("categories"), :as => "categories_index"

end
