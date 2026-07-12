# frozen_string_literal: true

# name: discourse-ai
# about: Enables integration between AI modules and features in Discourse
# meta_topic_id: 259214
# version: 0.0.1
# authors: Discourse
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-ai

require "tokenizers"
require "tiktoken_ruby"
require "discourse_ai/tokenizers"
require "ed25519"

enabled_site_setting :discourse_ai_enabled

register_asset "stylesheets/common/streaming.scss"
register_asset "stylesheets/common/ai-blinking-animation.scss"
register_asset "stylesheets/common/ai-user-settings.scss"
register_asset "stylesheets/common/ai-features.scss"

register_asset "stylesheets/admin/ai-features-editor.scss", :admin

register_asset "stylesheets/modules/translation/admin/translations.scss", :admin

register_asset "stylesheets/modules/ai-helper/common/ai-helper.scss"
register_asset "stylesheets/modules/ai-helper/desktop/ai-helper-fk-modals.scss", :desktop
register_asset "stylesheets/modules/ai-helper/mobile/ai-helper.scss", :mobile

register_asset "stylesheets/modules/summarization/common/ai-summary.scss"
register_asset "stylesheets/modules/summarization/desktop/ai-summary.scss", :desktop

register_asset "stylesheets/modules/summarization/common/ai-gists.scss"

register_asset "stylesheets/modules/admin-dashboard/common/admin-dashboard-highlight.scss"
register_asset "stylesheets/modules/ai-bot/common/bot-replies.scss"
register_asset "stylesheets/modules/ai-bot/common/ai-agent.scss"
register_asset "stylesheets/modules/ai-bot/common/ai-discobot-discoveries.scss"
register_asset "stylesheets/modules/ai-bot/mobile/ai-agent.scss", :mobile

register_asset "stylesheets/modules/ai-bot-conversations/common.scss"
register_asset "stylesheets/modules/ai-bot-conversations/docked-composer.scss"

register_asset "stylesheets/modules/embeddings/common/semantic-related-topics.scss"
register_asset "stylesheets/modules/embeddings/common/semantic-search.scss"

register_asset "stylesheets/modules/sentiment/common/dashboard.scss"

register_asset "stylesheets/modules/llms/common/ai-llms-editor.scss"
register_asset "stylesheets/modules/llms/common/ai-secret-selector.scss"
register_asset "stylesheets/modules/embeddings/common/ai-embedding-editor.scss"

register_asset "stylesheets/modules/llms/common/usage.scss"
register_asset "stylesheets/modules/llms/common/spam.scss"
register_asset "stylesheets/modules/llms/common/ai-llm-quotas.scss"
register_asset "stylesheets/modules/llms/common/ai-credit-bar.scss"

register_asset "stylesheets/modules/ai-bot/common/ai-tools.scss"

register_asset "stylesheets/modules/ai-bot/common/ai-artifact.scss"
register_asset "stylesheets/modules/ai-bot/common/ai-tool-approval.scss"

module ::DiscourseAi
  PLUGIN_NAME = "discourse-ai"

  def self.public_asset_path(name)
    File.expand_path(File.join(__dir__, "public", name))
  end
end

Rails.autoloaders.main.push_dir(File.join(__dir__, "lib"), namespace: DiscourseAi)

require_relative "lib/engine"
require_relative "lib/configuration/module"
require_relative "lib/mcp/oauth_token_store"
require_relative "lib/mcp/oauth_discovery"
require_relative "lib/mcp/oauth_client_registration"
require_relative "lib/mcp/oauth_flow"

# Other plugins can register features through this register.
DiscoursePluginRegistry.define_filtered_register(:external_ai_features)

DiscourseAi::Configuration::Module::NAMES.each do |module_name|
  register_site_setting_area("ai-features/#{module_name}")
end

after_initialize do
  if defined?(Rack::MiniProfiler)
    Rack::MiniProfiler.config.skip_paths << "/discourse-ai/ai-bot/artifacts"
  end

  # Avoid a mini_sql warning ("no type cast defined") by registering a halfvec text decoder.
  if !GlobalSetting.skip_db?
    if halfvec_oid = DB.query_single("SELECT oid FROM pg_type WHERE typname = 'halfvec'").first
      DB.type_map.add_coder(PG::TextDecoder::String.new(oid: halfvec_oid))
    end
  end

  # do not autoload this cause we may have no namespace
  require_relative "discourse_automation/llm_triage"
  require_relative "discourse_automation/llm_report"
  require_relative "discourse_automation/ai_tool_action"
  require_relative "discourse_automation/llm_agent_triage"
  require_relative "discourse_automation/llm_tagger"

  if respond_to?(:register_discourse_workflows_node)
    register_discourse_workflows_node do
      require_relative "discourse_workflows/nodes/ai_agent/v1"
      DiscourseWorkflows::Nodes::AiAgent::V1
    end
  end

  add_admin_route("discourse_ai.title", "discourse-ai", { use_new_show_route: true })

  register_seedfu_fixtures(Rails.root.join("plugins/discourse-ai/db/fixtures/agents"))

  [
    DiscourseAi::Embeddings::EntryPoint.new,
    DiscourseAi::Sentiment::EntryPoint.new,
    DiscourseAi::AiHelper::EntryPoint.new,
    DiscourseAi::Summarization::EntryPoint.new,
    DiscourseAi::AiBot::EntryPoint.new,
    DiscourseAi::AiModeration::EntryPoint.new,
    DiscourseAi::Translation::EntryPoint.new,
    DiscourseAi::Discover::EntryPoint.new,
  ].each { |a_module| a_module.inject_into(self) }

  register_problem_check ProblemCheck::AiLlmStatus
  #register_problem_check ProblemCheck::AiCreditSoftLimit
  #register_problem_check ProblemCheck::AiCreditHardLimit

  register_reviewable_type ReviewableAiChatMessage
  register_reviewable_type ReviewableAiPost
  register_reviewable_type ReviewableAiToolAction
  add_permitted_reviewable_param :reviewable_ai_tool_action, :post_id

  on(:reviewable_transitioned_to) do |new_status, reviewable|
    ModelAccuracy.adjust_model_accuracy(new_status, reviewable)
    if DiscourseAi::AiModeration::SpamScanner.enabled?
      DiscourseAi::AiModeration::SpamMetric.update(new_status, reviewable)
    end
  end

  # when an account is removed, clear the user's own logs and the logs tied to
  # the content being deleted with the account. the content callback runs before
  # discourse reassigns/soft-deletes the user's posts, so ownership is still intact.
  on(:user_destroyed) { |user| DiscourseAi::AiApiAuditLogCleaner.delete_for_user(user.id) }

  register_user_destroyer_on_content_deletion_callback(
    Proc.new { |user| DiscourseAi::AiApiAuditLogCleaner.delete_for_user_content(user) },
  )

  # outside account deletion, only purge logs once the content is permanently
  # gone; a soft-deleted (trashed) post or topic is still recoverable, so its
  # audit log must remain
  on(:post_destroyed) do |post|
    if !Post.with_deleted.exists?(post.id)
      DiscourseAi::AiApiAuditLogCleaner.delete_for_post(post.id)
    end
  end

  on(:topic_destroyed) do |topic|
    if !Topic.with_deleted.exists?(topic.id)
      DiscourseAi::AiApiAuditLogCleaner.delete_for_topic(topic.id)
    end
  end

  if Rails.env.test?
    require_relative "spec/support/embeddings_generation_stubs"
    require_relative "spec/support/fake_external_agent"
  end

  reloadable_patch do |plugin|
    Guardian.prepend DiscourseAi::GuardianExtensions
    Topic.prepend DiscourseAi::TopicExtensions
    Post.prepend DiscourseAi::PostExtensions
  end

  # AI bots reply via `skip_guardian: true`, so the reachability warning is misleading.
  register_modifier(:composer_mention_user_reason) do |reason, user|
    DiscourseAi::AiBot::EntryPoint.all_bot_ids.include?(user.id) ? nil : reason
  end

  register_modifier(:post_should_secure_uploads?) do |_, _, topic|
    if topic.private_message? && SharedAiConversation.exists?(target: topic)
      false
    else
      # revert to default behavior
      # even though this can be shortened this is the clearest way to express it
      nil
    end
  end

  add_api_key_scope(:ai, { update_agents: { actions: %w[discourse_ai/super_admin/ai_agents#update] } })

  add_api_key_scope(
    :ai,
    {
      manage_artifacts: {
        actions: %w[
          discourse_ai/super_admin/ai_artifacts#index
          discourse_ai/super_admin/ai_artifacts#show
          discourse_ai/super_admin/ai_artifacts#create
          discourse_ai/super_admin/ai_artifacts#update
          discourse_ai/super_admin/ai_artifacts#destroy
        ],
      },
    },
  )

  plugin_icons = %w[
    chart-column
    spell-check
    language
    images
    far-copy
    robot
    info
    bars-staggered
    far-circle-question
    face-smile
    face-meh
    face-angry
    circle-info
  ]
  plugin_icons.each { |icon| register_svg_icon(icon) }

  add_model_callback(DiscourseAutomation::Automation, :after_save) do
    DiscourseAi::Configuration::Feature.feature_cache.flush!
  end
end
