# frozen_string_literal: true

Chat::Engine.routes.draw do
  namespace :api, defaults: { format: :json } do
    get "/chatables" => "chatables#index"
    get "/channels" => "channels#index"
    get "/me/channels" => "current_user_channels#index"
    get "/me/threads" => "current_user_threads#index"
    post "/channels" => "channels#create"
    put "/channels/read" => "channels_read#update_all"
    put "/channels/:channel_id/read" => "channels_read#update"
    post "/channels/:channel_id/messages/:message_id/flags" => "channels_messages_flags#create"
    post "/channels/:channel_id/drafts" => "channels_drafts#create"
    post "/channels/:channel_id/messages/:message_id/interactions" =>
           "channels_messages_interactions#create"
    delete "/channels/:channel_id" => "channels#destroy"
    put "/channels/:channel_id" => "channels#update"
    get "/channels/:channel_id" => "channels#show"
    put "/channels/:channel_id/status" => "channels_status#update"
    get "/channels/:channel_id/messages" => "channel_messages#index"
    put "/channels/:channel_id/messages/:message_id" => "channel_messages#update"
    post "/channels/:channel_id/messages/moves" => "channels_messages_moves#create"
    delete "/channels/:channel_id/messages/:message_id/streaming" =>
             "channels_messages_streaming#destroy"
    post "/channels/:channel_id/invites" => "channels_invites#create"
    post "/channels/:channel_id/archives" => "channels_archives#create"
    get "/channels/:channel_id/memberships" => "channels_memberships#index"
    post "/channels/:channel_id/memberships" => "channels_memberships#create"
    delete "/channels/:channel_id/memberships/me" => "channels_current_user_membership#destroy"
    delete "/channels/:channel_id/memberships/me/follows" =>
             "channels_current_user_membership_follows#destroy"
    put "/channels/:channel_id/memberships/me" => "channels_current_user_membership#update"
    post "/channels/:channel_id/memberships/me" => "channels_current_user_membership#create"
    put "/channels/:channel_id/notifications-settings/me" =>
          "channels_current_user_notifications_settings#update"

    # Category chatables controller hints. Only used by staff members, we don't want to leak category permissions.
    get "/category-chatables/:id/permissions" => "category_chatables#permissions",
        :format => :json,
        :constraints => StaffConstraint.new

    # Hints for JIT warnings.
    get "/mentions/groups" => "hints#check_group_mentions", :format => :json

    get "/channels/:channel_id/threads" => "channel_threads#index"
    post "/channels/:channel_id/threads" => "channel_threads#create"
    put "/channels/:channel_id/threads/:thread_id" => "channel_threads#update"
    get "/channels/:channel_id/threads/:thread_id" => "channel_threads#show"
    get "/channels/:channel_id/threads/:thread_id/messages" => "channel_thread_messages#index"
    put "/channels/:channel_id/threads/:thread_id/read" => "channels_threads_read#update"
    post "/channels/:channel_id/threads/:thread_id/drafts" => "channels_threads_drafts#create"
    put "/channels/:channel_id/threads/:thread_id/notifications-settings/me" =>
          "channel_threads_current_user_notifications_settings#update"
    post "/channels/:channel_id/threads/:thread_id/mark-thread-title-prompt-seen/me" =>
           "channel_threads_current_user_title_prompt_seen#update"
    post "/direct-message-channels" => "direct_messages#create"

    put "/channels/:channel_id/messages/:message_id/restore" => "channel_messages#restore"
    delete "/channels/:channel_id/messages/:message_id" => "channel_messages#destroy"
    delete "/channels/:channel_id/messages" => "channel_messages#bulk_destroy"
  end

  namespace :admin, defaults: { format: :json, constraints: StaffConstraint.new } do
    post "export/messages" => "export#export_messages"
  end

  # direct_messages_controller routes
  get "/direct_messages" => "direct_messages#index"

  # incoming_webhooks_controller routes
  post "/hooks/:key" => "incoming_webhooks#create_message"

  # incoming_webhooks_controller routes
  post "/hooks/:key/slack" => "incoming_webhooks#create_message_slack_compatible"

  # chat_controller routes
  get "/" => "chat#respond"
  get "/new-message" => "chat#respond"
  get "/direct-messages" => "chat#respond"
  get "/channels" => "chat#respond"
  get "/threads" => "chat#respond"
  get "/browse" => "chat#respond"
  get "/browse/all" => "chat#respond"
  get "/browse/closed" => "chat#respond"
  get "/browse/open" => "chat#respond"
  get "/browse/archived" => "chat#respond"
  post "/dismiss-retention-reminder" => "chat#dismiss_retention_reminder"
  put ":chat_channel_id/react/:message_id" => "chat#react"
  put "/:chat_channel_id/:message_id/rebake" => "chat#rebake"
  post "/:chat_channel_id/quote" => "chat#quote_messages"
  put "/user_chat_enabled/:user_id" => "chat#set_user_chat_status"
  post "/:chat_channel_id" => "api/channel_messages#create"

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
  get "#{base_c_route}/t/:thread_id/:message_id" => "chat#respond"

  base_channel_route = "/channel/:channel_id/:channel_title"
  redirect_base = "/chat/c/%{channel_title}/%{channel_id}"

  get base_channel_route, to: redirect(redirect_base)

  %w[info info/about info/members info/settings].each do |route|
    get "#{base_channel_route}/#{route}", to: redirect("#{redirect_base}/#{route}")
  end
end
