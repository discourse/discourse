# frozen_string_literal: true

Voice::Engine.routes.draw do
  resources :rooms do
    member do
      post :join
      post :heartbeat
      delete :leave
      get :participants
      post :signal
      get :chat_session
      post :chat_session, action: :ensure_chat_session, as: :ensure_chat_session
      post :chat_message
      post :toggle_mute
      post :state
      post :livekit_token
      post :recording, action: :start_recording, as: :start_recording
      delete :recording, action: :stop_recording, as: :stop_recording
      delete :kick
      post :flag
      post :request_to_speak
      delete :request_to_speak, action: :withdraw_request_to_speak, as: :withdraw_request_to_speak
    end

    resources :memberships, controller: "room_memberships", only: %i[index create update destroy]

    resources :invites, only: %i[create] do
      collection { get :suggestions }
    end
  end

  resources :calls, only: %i[create]

  # LiveKit server webhooks — machine-to-machine, authenticated by the
  # signature on the request body, not by a user session.
  post "livekit/webhook" => "livekit_webhooks#create"

  get "contacts" => "contacts#index"
  get "chat_threads/:id" => "chat_threads#show", :constraints => { id: /\d+/ }
  get "r/:slug" => "page#show", :format => false
  get "r/:slug/invited-by/:username" => "page#show", :format => false
end

Discourse::Application.routes.draw do
  scope "/admin/plugins/voice", constraints: AdminConstraint.new do
    scope format: false do
      get "/voice-rooms" => "voice/admin#index"
      get "/voice-rooms/new" => "voice/admin#new"
      get "/voice-rooms/:id" => "voice/admin#edit"
      get "/voice-dashboard" => "voice/admin#index"
      get "/voice-recordings" => "voice/admin#index"
    end

    scope format: :json do
      get "/rooms" => "voice/admin_rooms#index"
      get "/rooms/:id" => "voice/admin_rooms#show"
      post "/rooms" => "voice/admin_rooms#create"
      put "/rooms/:id" => "voice/admin_rooms#update"
      delete "/rooms/:id" => "voice/admin_rooms#destroy"
      post "/rooms/:id/end_call" => "voice/admin_rooms#end_call"

      get "/stats/overview" => "voice/admin_stats#overview"
      get "/stats/rooms" => "voice/admin_stats#rooms"
      get "/stats/users" => "voice/admin_stats#users"

      get "/livekit/status" => "voice/admin_livekit#status"
      post "/livekit/probe" => "voice/admin_livekit#probe"

      get "/recordings" => "voice/admin_recordings#index"
    end
  end
end
