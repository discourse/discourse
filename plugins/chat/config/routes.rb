# frozen_string_literal: true

Chat::Engine.routes.draw do
  namespace :api, defaults: { format: :json } do
    get "/chatables" => "chatables#index"
    get "/channels" => "channels#index"
    get "/channels/me" => "current_user_channels#index"
    post "/channels" => "channels#create"
    put "/channels/read/" => "reads#update_all"
    put "/channels/:channel_id/read/:message_id" => "reads#update"
    delete "/channels/:channel_id" => "channels#destroy"
    put "/channels/:channel_id" => "channels#update"
    get "/channels/:channel_id" => "channels#show"
    put "/channels/:channel_id/status" => "channels_status#update"
    post "/channels/:channel_id/messages/moves" => "channels_messages_moves#create"
    post "/channels/:channel_id/archives" => "channels_archives#create"
    get "/channels/:channel_id/memberships" => "channels_memberships#index"
    delete "/channels/:channel_id/memberships/me" => "channels_current_user_membership#destroy"
    post "/channels/:channel_id/memberships/me" => "channels_current_user_membership#create"
    put "/channels/:channel_id/notifications-settings/me" =>
          "channels_current_user_notifications_settings#update"

    # Category chatables controller hints. Only used by staff members, we don't want to leak category permissions.
    get "/category-chatables/:id/permissions" => "category_chatables#permissions",
        :format => :json,
        :constraints => StaffConstraint.new

    # Hints for JIT warnings.
    get "/mentions/groups" => "hints#check_group_mentions", :format => :json

    get "/channels/:channel_id/threads/:thread_id" => "channel_threads#show"
    put "/channels/:channel_id/threads/:thread_id/read" => "thread_reads#update"

    put "/channels/:channel_id/messages/:message_id/restore" => "channel_messages#restore"
    delete "/channels/:channel_id/messages/:message_id" => "channel_messages#destroy"
  end

  # direct_messages_controller routes
  get "/direct_messages" => "direct_messages#index"
  post "/direct_messages/create" => "direct_messages#create"

  # incoming_webhooks_controller routes
  post "/hooks/:key" => "incoming_webhooks#create_message"

  # incoming_webhooks_controller routes
  post "/hooks/:key/slack" => "incoming_webhooks#create_message_slack_compatible"

  # chat_controller routes
  get "/" => "chat#respond"
  get "/browse" => "chat#respond"
  get "/browse/all" => "chat#respond"
  get "/browse/closed" => "chat#respond"
  get "/browse/open" => "chat#respond"
  get "/browse/archived" => "chat#respond"
  get "/draft-channel" => "chat#respond"
  post "/enable" => "chat#enable_chat"
  post "/disable" => "chat#disable_chat"
  post "/dismiss-retention-reminder" => "chat#dismiss_retention_reminder"
  get "/:chat_channel_id/messages" => "chat#messages"
  get "/message/:message_id" => "chat#message_link"
  put ":chat_channel_id/edit/:message_id" => "chat#edit_message"
  put ":chat_channel_id/react/:message_id" => "chat#react"
  put "/:chat_channel_id/:message_id/rebake" => "chat#rebake"
  post "/:chat_channel_id/:message_id/flag" => "chat#flag"
  post "/:chat_channel_id/quote" => "chat#quote_messages"
  get "/lookup/:message_id" => "chat#lookup_message"
  put "/:chat_channel_id/read/:message_id" => "chat#update_user_last_read"
  put "/user_chat_enabled/:user_id" => "chat#set_user_chat_status"
  put "/:chat_channel_id/invite" => "chat#invite_users"
  post "/drafts" => "chat#set_draft"
  post "/:chat_channel_id" => "chat#create_message"
  put "/flag" => "chat#flag"
  get "/emojis" => "emojis#index"

  base_c_route = "/c/:channel_title/:channel_id"
  get base_c_route => "chat#respond", :as => "channel"
  get "#{base_c_route}/:message_id" => "chat#respond"

  %w[info info/about info/members info/settings].each do |route|
    get "#{base_c_route}/#{route}" => "chat#respond"
  end

  # /channel -> /c redirects
  get "/channel/:channel_id", to: redirect("/chat/c/-/%{channel_id}")

  get "#{base_c_route}/t/:thread_id" => "chat#respond"

  base_channel_route = "/channel/:channel_id/:channel_title"
  redirect_base = "/chat/c/%{channel_title}/%{channel_id}"

  get base_channel_route, to: redirect(redirect_base)

  %w[info info/about info/members info/settings].each do |route|
    get "#{base_channel_route}/#{route}", to: redirect("#{redirect_base}/#{route}")
  end
end
