# frozen_string_literal: true

TangyzenPlugin::Engine.routes.draw do
  # Deals routes
  resources :deals, only: [:index, :show, :create, :update, :destroy] do
    member do
      post :like
      delete :unlike
      post :save
      delete :unsave
      put :feature
    end
  end
  
  get '/deals/featured' => 'deals#featured'
  get '/deals/trending' => 'deals#trending'

  # Music routes
  resources :music, only: [:index, :show, :create, :update, :destroy] do
    member do
      post :like
      delete :unlike
      post :save
      delete :unsave
      put :feature
    end
  end
  
  get '/music/featured' => 'music#featured'
  get '/music/trending' => 'music#trending'

  # Movies routes
  resources :movies, only: [:index, :show, :create, :update, :destroy] do
    member do
      post :like
      delete :unlike
      post :save
      delete :unsave
      put :feature
    end
  end
  
  get '/movies/featured' => 'movies#featured'
  get '/movies/trending' => 'movies#trending'

  # Reviews routes
  resources :reviews, only: [:index, :show, :create, :update, :destroy] do
    member do
      post :like
      delete :unlike
      post :save
      delete :unsave
      put :feature
    end
  end
  
  get '/reviews/featured' => 'reviews#featured'
  get '/reviews/trending' => 'reviews#trending'

  # Arts routes
  resources :arts, only: [:index, :show, :create, :update, :destroy] do
    member do
      post :like
      delete :unlike
      post :save
      delete :unsave
      put :feature
    end
  end
  
  get '/arts/featured' => 'arts#featured'
  get '/arts/trending' => 'arts#trending'

  # Blogs routes
  resources :blogs, only: [:index, :show, :create, :update, :destroy] do
    member do
      post :like
      delete :unlike
      post :save
      delete :unsave
      put :feature
    end
  end
  
  get '/blogs/featured' => 'blogs#featured'
  get '/blogs/trending' => 'blogs#trending'

  # Gaming routes (NEW)
  resources :gaming, only: [:index, :show, :create, :update, :destroy] do
    member do
      post :like
      delete :unlike
      post :save
      delete :unsave
      put :feature
    end
  end
  
  get '/gaming/featured' => 'gaming#featured'
  get '/gaming/trending' => 'gaming#trending'

  # Web3 / OpenSea routes (NEW)
  namespace :web3 do
    get '/nfts' => 'web3#nfts'
    get '/collections' => 'web3#collections'
    get '/collections/:slug' => 'web3#show_collection'
    get '/nfts/:contract_address/:token_id' => 'web3#show_nft'
    get '/trending' => 'web3#trending'
    get '/search' => 'web3#search'
    post '/sync_trending' => 'web3#sync_trending'
    post '/connect_wallet' => 'web3#connect_wallet'
    delete '/disconnect_wallet' => 'web3#disconnect_wallet'
    get '/my_nfts' => 'web3#my_nfts'
    get '/floor_price' => 'web3#floor_price'
  end

  # Admin routes
  namespace :admin do
    get '/' => 'admin#overview'
    get '/dashboard' => 'admin#overview'
    get '/stats' => 'admin#overview'
    
    # Content management
    get '/content' => 'admin#content_list'
    get '/content/:type' => 'admin#content_list'
    patch '/content/:type/:id' => 'admin#update_content'
    delete '/content/:type/:id' => 'admin#delete_content'
    post '/content/:type/:id/feature' => 'admin#feature_content'
    post '/content/:type/:id/unfeature' => 'admin#unfeature_content'
    
    # User management
    get '/users' => 'admin#users_list'
    
    # Analytics
    get '/analytics' => 'admin#analytics'
    
    # Web3 sync
    post '/web3/sync' => 'admin#sync_web3_data'
    
    # Settings
    get '/settings' => 'admin#settings'
    put '/settings' => 'admin#update_settings'
    
    # Data consistency
    get '/data-consistency' => 'admin#check_data_consistency'
    post '/repair-data' => 'admin#repair_data'
  end
end
