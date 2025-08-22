# frozen_string_literal: true

DiscourseAi::Engine.routes.draw do
  scope module: :ai_helper, path: "/ai-helper", defaults: { format: :json } do
    post "suggest" => "assistant#suggest"
    post "suggest_title" => "assistant#suggest_title"
    post "suggest_category" => "assistant#suggest_category"
    post "suggest_tags" => "assistant#suggest_tags"
    post "stream_suggestion" => "assistant#stream_suggestion"
    post "caption_image" => "assistant#caption_image"
  end

  scope module: :embeddings, path: "/embeddings", defaults: { format: :json } do
    get "semantic-search" => "embeddings#search"
    get "quick-search" => "embeddings#quick_search"
  end

  scope module: :discord, path: "/discord", defaults: { format: :json } do
    post "interactions" => "bot#interactions"
  end

  scope module: :ai_bot, path: "/ai-bot", defaults: { format: :json } do
    get "bot-username" => "bot#show_bot_username"
    get "post/:post_id/show-debug-info" => "bot#show_debug_info"
    get "show-debug-info/:id" => "bot#show_debug_info_by_id"
    post "post/:post_id/stop-streaming" => "bot#stop_streaming_response"

    get "discover" => "bot#discover"
    post "discover/continue-convo" => "bot#discover_continue_convo"
  end

  scope module: :ai_bot, path: "/ai-bot/shared-ai-conversations" do
    post "/" => "shared_ai_conversations#create"
    delete "/:share_key" => "shared_ai_conversations#destroy"
    get "/:share_key" => "shared_ai_conversations#show"
    get "/asset/:version/:name" => "shared_ai_conversations#asset"
    get "/preview/:topic_id" => "shared_ai_conversations#preview"
  end

  scope module: :ai_bot, path: "/ai-bot/conversations" do
    get "/" => "conversations#index"
  end

  scope module: :ai_bot, path: "/ai-bot/artifacts" do
    get "/:id" => "artifacts#show"
    get "/:id/:version" => "artifacts#show"
  end

  scope module: :ai_bot, path: "/ai-bot/artifact-key-values/:artifact_id" do
    get "/" => "artifact_key_values#index"
    post "/" => "artifact_key_values#set"
    delete "/:key" => "artifact_key_values#destroy"
    delete "/" => "artifact_key_values#destroy"
  end

  scope module: :summarization, path: "/summarization", defaults: { format: :json } do
    get "/t/:topic_id" => "summary#show", :constraints => { topic_id: /\d+/ }
    put "/regen_gist" => "summary#regen_gist"
    get "/channels/:channel_id" => "chat_summary#show"
  end

  scope module: :sentiment, path: "/sentiment", defaults: { format: :json } do
    get "/posts" => "sentiment#posts", :constraints => StaffConstraint.new
  end
end

Discourse::Application.routes.draw do
  mount ::DiscourseAi::Engine, at: "discourse-ai"

  get "admin/dashboard/sentiment" => "discourse_ai/admin/dashboard#sentiment",
      :constraints => StaffConstraint.new

  scope "/admin/plugins/discourse-ai", constraints: AdminConstraint.new do
    resources :ai_artifacts,
              only: %i[index show create update destroy],
              path: "ai-artifacts",
              controller: "discourse_ai/admin/ai_artifacts",
              defaults: {
                format: :json,
              }

    resources :ai_personas,
              only: %i[index new create edit update destroy],
              path: "ai-personas",
              controller: "discourse_ai/admin/ai_personas"

    post "/ai-personas/stream-reply" => "discourse_ai/admin/ai_personas#stream_reply"

    resources(
      :ai_tools,
      only: %i[index new create edit update destroy],
      path: "ai-tools",
      controller: "discourse_ai/admin/ai_tools",
    )

    post "/ai-tools/:id/test", to: "discourse_ai/admin/ai_tools#test"
    get "/ai-tools/:id/export", to: "discourse_ai/admin/ai_tools#export", format: :json
    post "/ai-tools/import", to: "discourse_ai/admin/ai_tools#import"

    post "/ai-personas/:id/create-user", to: "discourse_ai/admin/ai_personas#create_user"
    get "/ai-personas/:id/export", to: "discourse_ai/admin/ai_personas#export", format: :json
    post "/ai-personas/import", to: "discourse_ai/admin/ai_personas#import"

    put "/ai-personas/:id/files/remove", to: "discourse_ai/admin/ai_personas#remove_file"
    get "/ai-personas/:id/files/status", to: "discourse_ai/admin/ai_personas#indexing_status_check"

    post "/rag-document-fragments/files/upload",
         to: "discourse_ai/admin/rag_document_fragments#upload_file"
    get "/rag-document-fragments/files/status",
        to: "discourse_ai/admin/rag_document_fragments#indexing_status_check"

    get "/ai-usage", to: "discourse_ai/admin/ai_usage#show"
    get "/ai-usage-report", to: "discourse_ai/admin/ai_usage#report"
    get "/ai-spam", to: "discourse_ai/admin/ai_spam#show"
    put "/ai-spam", to: "discourse_ai/admin/ai_spam#update"
    post "/ai-spam/test", to: "discourse_ai/admin/ai_spam#test"
    post "/ai-spam/fix-errors", to: "discourse_ai/admin/ai_spam#fix_errors"

    get "/ai-translations", to: "discourse_ai/admin/ai_translations#show"

    resources :ai_llms,
              only: %i[index new create edit update destroy],
              path: "ai-llms",
              controller: "discourse_ai/admin/ai_llms" do
      collection { get :test }
    end

    resources :ai_llm_quotas,
              controller: "discourse_ai/admin/ai_llm_quotas",
              path: "quotas",
              only: %i[index create update destroy]

    resources :ai_embeddings,
              only: %i[index new create edit update destroy],
              path: "ai-embeddings",
              controller: "discourse_ai/admin/ai_embeddings" do
      collection { get :test }
    end

    resources :ai_features,
              only: %i[index edit],
              path: "ai-features",
              controller: "discourse_ai/admin/ai_features"
  end
end

Discourse::Application.routes.append do
  get "u/:username/preferences/ai" => "users#preferences",
      :constraints => {
        username: RouteFormat.username,
      }
end
