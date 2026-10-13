# frozen_string_literal: true

Live::Engine.routes.draw do
  resources :rooms do
    member do
      post :invite_agent
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

  get "agents" => "agents#index"

  # LiveKit server webhooks — machine-to-machine, authenticated by the
  # signature on the request body, not by a user session.
  post "livekit/webhook" => "livekit_webhooks#create"

  get "contacts" => "contacts#index"
  get "chat_threads/:id" => "chat_threads#show", :constraints => { id: /\d+/ }
  get "r/:slug" => "page#show", :format => false
  get "r/:slug/invited-by/:username" => "page#show",
      :format => false,
      :constraints => {
        username: RouteFormat.username,
      }
end

Discourse::Application.routes.draw do
  scope "/admin/plugins/live", constraints: AdminConstraint.new do
    scope format: false do
      get "/live-rooms" => "live/admin#index"
      get "/live-rooms/new" => "live/admin#new"
      get "/live-rooms/:id" => "live/admin#edit"
      get "/live-dashboard" => "live/admin#index"
      get "/live-recordings" => "live/admin#index"
    end

    scope format: :json do
      get "/rooms" => "live/admin_rooms#index"
      get "/rooms/:id" => "live/admin_rooms#show"
      post "/rooms" => "live/admin_rooms#create"
      put "/rooms/:id" => "live/admin_rooms#update"
      delete "/rooms/:id" => "live/admin_rooms#destroy"
      post "/rooms/:id/end_call" => "live/admin_rooms#end_call"

      get "/stats/overview" => "live/admin_stats#overview"
      get "/stats/rooms" => "live/admin_stats#rooms"
      get "/stats/users" => "live/admin_stats#users"

      get "/livekit/status" => "live/admin_livekit#status"
      post "/livekit/probe" => "live/admin_livekit#probe"

      get "/recordings" => "live/admin_recordings#index"
    end
  end

  # Links and LiveKit webhook URLs configured before the plugin was renamed.
  post "/voice/livekit/webhook" => "live/livekit_webhooks#create"
  get "/voice/r/*path",
      to:
        redirect { |params, request|
          [
            "#{Discourse.base_path}/live/r/#{params[:path]}",
            request.query_string.presence,
          ].compact.join("?")
        },
      format: false
end
