require 'sidekiq/web'

require_dependency 'admin_constraint'

# This used to be User#username_format, but that causes a preload of the User object
# and makes Guard not work properly. 
USERNAME_ROUTE_FORMAT = /[A-Za-z0-9\._]+/

Discourse::Application.routes.draw do

  match "/404", :to => "exceptions#not_found"

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
    resources :users, id: USERNAME_ROUTE_FORMAT do
      collection do
        get 'list/:query' => 'users#index'
        put 'approve-bulk' => 'users#approve_bulk'
      end
      put 'ban' => 'users#ban'
      put 'delete_all_posts' => 'users#delete_all_posts'
      put 'unban' => 'users#unban'
      put 'revoke_admin' => 'users#revoke_admin'
      put 'grant_admin' => 'users#grant_admin'
      put 'approve' => 'users#approve'
      post 'refresh_browsers' => 'users#refresh_browsers'
    end

    resources :impersonate
    resources :email_logs do
      collection do
        post 'test' => 'email_logs#test'
      end
    end
    get 'customize' => 'site_customizations#index'
    get 'flags' => 'flags#index'
    get 'flags/:filter' => 'flags#index'
    post 'flags/clear/:id' => 'flags#clear'
    resources :site_customizations
    resources :export
    get 'version_check' => 'versions#show'
  end

  get 'email_preferences' => 'email#preferences_redirect'
  get 'email/unsubscribe/:key' => 'email#unsubscribe', as: 'email_unsubscribe'
  post 'email/resubscribe/:key' => 'email#resubscribe', as: 'email_resubscribe'


  resources :session, id: USERNAME_ROUTE_FORMAT do 
    collection do 
      post 'forgot_password'
    end
  end  

  resources :users, :except => [:show, :update] do 
    collection do 
      get 'check_username'
      get 'is_local_username'
    end
  end

  resources :static
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
  get 'users/:username/private-messages' => 'user_actions#private_messages', :format => false, :constraints => {:username => USERNAME_ROUTE_FORMAT}
  get 'users/:username' => 'users#show', :format => false, :constraints => {:username => USERNAME_ROUTE_FORMAT}
  put 'users/:username' => 'users#update', :format => false, :constraints => {:username => USERNAME_ROUTE_FORMAT}  
  get 'users/:username/preferences' => 'users#preferences', :format => false, :constraints => {:username => USERNAME_ROUTE_FORMAT}, :as => :email_preferences
  get 'users/:username/preferences/email' => 'users#preferences', :format => false, :constraints => {:username => USERNAME_ROUTE_FORMAT}
  put 'users/:username/preferences/email' => 'users#change_email', :format => false, :constraints => {:username => USERNAME_ROUTE_FORMAT}  
  get 'users/:username/preferences/username' => 'users#preferences', :format => false, :constraints => {:username => USERNAME_ROUTE_FORMAT}
  put 'users/:username/preferences/username' => 'users#username', :format => false, :constraints => {:username => USERNAME_ROUTE_FORMAT}
  get 'users/:username/avatar(/:size)' => 'users#avatar', :constraints => {:username => USERNAME_ROUTE_FORMAT}
  get 'users/:username/invited' => 'users#invited', :constraints => {:username => USERNAME_ROUTE_FORMAT}

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

  resources :notifications
  resources :categories

  match "/auth/:provider/callback", to: "users/omniauth_callbacks#complete"

  get 'twitter/frame' => 'twitter#frame'
  get 'twitter/complete' => 'twitter#complete'

  get 'facebook/frame' => 'facebook#frame'
  get 'facebook/complete' => 'facebook#complete'
  
  resources :clicks do
    collection do
      get 'track' => 'clicks#track'
    end
  end

  get 'excerpt' => 'excerpt#show'

  resources :post_actions do
    collection do
      get 'users' => 'post_actions#users'
      post 'clear_flags' => 'post_actions#clear_flags'
    end
  end
  resources :user_actions

  get 'category/:category' => 'list#category'
  get 'popular' => 'list#index'
  get 'popular/more' => 'list#index'
  get 'categories' => 'categories#index'
  get 'favorited' => 'list#favorited'
  get 'favorited/more' => 'list#favorited'
  get 'read' => 'list#read'
  get 'read/more' => 'list#read'
  get 'unread' => 'list#unread'
  get 'unread/more' => 'list#unread'
  get 'new' => 'list#new'
  get 'new/more' => 'list#new'
  get 'posted' => 'list#posted'
  get 'posted/more' => 'list#posted'
  get 'category/:category' => 'list#category', as: 'category'
  get 'category/:category/more' => 'list#category', as: 'category'

  get 'search' => 'search#query'

  # Topics resource
  get 't/:id' => 'topics#show'
  delete 't/:id' => 'topics#destroy'
  put 't/:id' => 'topics#update'
  post 't' => 'topics#create'  
  post 'topics/timings' => 'topics#timings'

  # Legacy route for old avatars
  get 'threads/:topic_id/:post_number/avatar' => 'topics#avatar', :constraints => {:topic_id => /\d+/, :post_number => /\d+/}

  # Topic routes  
  get 't/:slug/:topic_id/best_of' => 'topics#show', :constraints => {:topic_id => /\d+/, :post_number => /\d+/}
  get 't/:topic_id/best_of' => 'topics#show', :constraints => {:topic_id => /\d+/, :post_number => /\d+/}
  put 't/:slug/:topic_id' => 'topics#update', :constraints => {:topic_id => /\d+/}
  put 't/:slug/:topic_id/star' => 'topics#star', :constraints => {:topic_id => /\d+/}
  put 't/:topic_id/star' => 'topics#star', :constraints => {:topic_id => /\d+/}
  put 't/:slug/:topic_id/status' => 'topics#status', :constraints => {:topic_id => /\d+/}
  put 't/:topic_id/status' => 'topics#status', :constraints => {:topic_id => /\d+/}
  put 't/:topic_id/mute' => 'topics#mute', :constraints => {:topic_id => /\d+/}
  put 't/:topic_id/unmute' => 'topics#unmute', :constraints => {:topic_id => /\d+/}

  get 't/:topic_id/:post_number' => 'topics#show', :constraints => {:topic_id => /\d+/, :post_number => /\d+/}
  get 't/:slug/:topic_id' => 'topics#show', :constraints => {:topic_id => /\d+/}
  get 't/:slug/:topic_id/:post_number' => 'topics#show', :constraints => {:topic_id => /\d+/, :post_number => /\d+/}  
  post 't/:topic_id/timings' => 'topics#timings', :constraints => {:topic_id => /\d+/}
  post 't/:topic_id/invite' => 'topics#invite', :constraints => {:topic_id => /\d+/}
  post 't/:topic_id/move-posts' => 'topics#move_posts', :constraints => {:topic_id => /\d+/}
  delete 't/:topic_id/timings' => 'topics#destroy_timings', :constraints => {:topic_id => /\d+/}

  post 't/:topic_id/notifications' => 'topics#set_notifications' , :constraints => {:topic_id => /\d+/}
  

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

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  root :to => 'list#index'

end
