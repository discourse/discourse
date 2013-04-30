require 'sidekiq/web'

require_dependency 'admin_constraint'
require_dependency 'homepage_constraint'

# This used to be User#username_format, but that causes a preload of the User object
# and makes Guard not work properly.
USERNAME_ROUTE_FORMAT = /[A-Za-z0-9\_]+/ unless defined? USERNAME_ROUTE_FORMAT

Discourse::Application.routes.draw do

  match "/404", to: "exceptions#not_found"

  mount Sidekiq::Web => '/sidekiq', constraints: AdminConstraint.new

  resources :forums do
    collection do
      get 'request_access'
      post 'request_access_submit'
    end
  end
  get 'srv/status' => 'forums#status'

  namespace :admin, constraints: AdminConstraint.new do
    get '' => 'admin#index'

    resources :site_settings
    get 'reports/:type' => 'reports#show'

    resources :groups
    resources :users, id: USERNAME_ROUTE_FORMAT do
      collection do
        get 'list/:query' => 'users#index'
        put 'approve-bulk' => 'users#approve_bulk'
      end
      put 'ban'
      put 'delete_all_posts'
      put 'unban'
      put 'revoke_admin'
      put 'grant_admin'
      put 'revoke_moderation'
      put 'grant_moderation'
      put 'approve'
      post 'refresh_browsers'
    end

    resources :impersonate
    resources :email_logs do
      collection do
        post 'test'
      end
    end
    get 'customize' => 'site_customizations#index'
    get 'flags' => 'flags#index'
    get 'flags/:filter' => 'flags#index'
    post 'flags/clear/:id' => 'flags#clear'
    resources :site_customizations
    resources :site_contents
    resources :site_content_types
    resources :export
    get 'version_check' => 'versions#show'
    resources :dashboard, only: [:index] do
      collection do
        get 'problems'
      end
    end
    resources :api, only: [:index] do
      collection do
        post 'generate_key'
      end
    end
  end

  get 'email_preferences' => 'email#preferences_redirect'
  get 'email/unsubscribe/:key' => 'email#unsubscribe', as: 'email_unsubscribe'
  post 'email/resubscribe/:key' => 'email#resubscribe', as: 'email_resubscribe'


  resources :session, id: USERNAME_ROUTE_FORMAT, only: [:create, :destroy] do
    collection do
      post 'forgot_password'
    end
  end

  resources :users, except: [:show, :update] do
    collection do
      get 'check_username'
      get 'is_local_username'
    end
  end

  resources :static
  post 'login' => 'static#enter'
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
  get 'users/:username' => 'users#show', constraints: {username: USERNAME_ROUTE_FORMAT}
  put 'users/:username' => 'users#update', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/preferences' => 'users#preferences', constraints: {username: USERNAME_ROUTE_FORMAT}, as: :email_preferences
  get 'users/:username/preferences/email' => 'users#preferences', constraints: {username: USERNAME_ROUTE_FORMAT}
  put 'users/:username/preferences/email' => 'users#change_email', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/preferences/username' => 'users#preferences', constraints: {username: USERNAME_ROUTE_FORMAT}
  put 'users/:username/preferences/username' => 'users#username', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/avatar(/:size)' => 'users#avatar', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/invited' => 'users#invited', constraints: {username: USERNAME_ROUTE_FORMAT}
  get 'users/:username/send_activation_email' => 'users#send_activation_email', constraints: {username: USERNAME_ROUTE_FORMAT}

  resources :uploads


  get 'posts/by_number/:topic_id/:post_number' => 'posts#by_number'
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
  resources :categories

  match "/auth/:provider/callback", to: "users/omniauth_callbacks#complete"
  match "/auth/failure", to: "users/omniauth_callbacks#failure"

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
  resources :education

  get 'category/:category.rss' => 'list#category_feed', format: :rss, as: 'category_feed'
  get 'category/:category' => 'list#category'
  get 'category/:category' => 'list#category', as: 'category'
  get 'category/:category/more' => 'list#category', as: 'category'
  get 'categories' => 'categories#index'

  # We've renamed popular to latest. If people access it we want a permanent redirect.
  get 'popular' => 'list#popular_redirect'
  get 'popular/more' => 'list#popular_redirect'

  [:latest, :hot, :favorited, :read, :posted, :unread, :new].each do |filter|
    get "#{filter}" => "list##{filter}"
    get "#{filter}/more" => "list##{filter}"
  end

  get 'search' => 'search#query'

  # Topics resource
  get 't/:id' => 'topics#show'
  delete 't/:id' => 'topics#destroy'
  put 't/:id' => 'topics#update'
  post 't' => 'topics#create'
  post 'topics/timings'
  get 'topics/similar_to'

  # Legacy route for old avatars
  get 'threads/:topic_id/:post_number/avatar' => 'topics#avatar', constraints: {topic_id: /\d+/, post_number: /\d+/}

  # Topic routes
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

  get 't/:topic_id/:post_number' => 'topics#show', constraints: {topic_id: /\d+/, post_number: /\d+/}
  get 't/:slug/:topic_id.rss' => 'topics#feed', format: :rss, constraints: {topic_id: /\d+/}
  get 't/:slug/:topic_id' => 'topics#show', constraints: {topic_id: /\d+/}
  get 't/:slug/:topic_id/:post_number' => 'topics#show', constraints: {topic_id: /\d+/, post_number: /\d+/}
  post 't/:topic_id/timings' => 'topics#timings', constraints: {topic_id: /\d+/}
  post 't/:topic_id/invite' => 'topics#invite', constraints: {topic_id: /\d+/}
  post 't/:topic_id/move-posts' => 'topics#move_posts', constraints: {topic_id: /\d+/}
  delete 't/:topic_id/timings' => 'topics#destroy_timings', constraints: {topic_id: /\d+/}

  post 't/:topic_id/notifications' => 'topics#set_notifications' , constraints: {topic_id: /\d+/}

  get 'md/:topic_id(/:post_number)' => 'posts#markdown'


  resources :invites
  delete 'invites' => 'invites#destroy'

  get 'request_access' => 'request_access#new'
  post 'request_access' => 'request_access#create'

  get 'onebox' => 'onebox#show'

  get 'error' => 'forums#error'

  get 'message-bus/poll' => 'message_bus#poll'

  get 'draft' => 'draft#show'
  post 'draft' => 'draft#update'
  delete 'draft' => 'draft#destroy'

  get 'robots.txt' => 'robots_txt#index'

  [:latest, :hot, :unread, :new, :favorited, :read, :posted].each do |filter|
    root to: "list##{filter}", constraints: HomePageConstraint.new("#{filter}")
  end
  # special case for categories
  root to: "categories#index", constraints: HomePageConstraint.new("categories")

end
