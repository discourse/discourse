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

register_asset "stylesheets/admin/ai-features-editor.scss"

register_asset "stylesheets/modules/translation/common/admin-translations.scss"

register_asset "stylesheets/modules/ai-helper/common/ai-helper.scss"
register_asset "stylesheets/modules/ai-helper/desktop/ai-helper-fk-modals.scss", :desktop
register_asset "stylesheets/modules/ai-helper/mobile/ai-helper.scss", :mobile

register_asset "stylesheets/modules/summarization/common/ai-summary.scss"
register_asset "stylesheets/modules/summarization/desktop/ai-summary.scss", :desktop

register_asset "stylesheets/modules/summarization/common/ai-gists.scss"

register_asset "stylesheets/modules/ai-bot/common/bot-replies.scss"
register_asset "stylesheets/modules/ai-bot/common/ai-persona.scss"
register_asset "stylesheets/modules/ai-bot/common/ai-discobot-discoveries.scss"
register_asset "stylesheets/modules/ai-bot/mobile/ai-persona.scss", :mobile

register_asset "stylesheets/modules/ai-bot-conversations/common.scss"

register_asset "stylesheets/modules/embeddings/common/semantic-related-topics.scss"
register_asset "stylesheets/modules/embeddings/common/semantic-search.scss"

register_asset "stylesheets/modules/sentiment/common/dashboard.scss"

register_asset "stylesheets/modules/llms/common/ai-llms-editor.scss"
register_asset "stylesheets/modules/embeddings/common/ai-embedding-editor.scss"

register_asset "stylesheets/modules/llms/common/usage.scss"
register_asset "stylesheets/modules/llms/common/spam.scss"
register_asset "stylesheets/modules/llms/common/ai-llm-quotas.scss"
register_asset "stylesheets/modules/llms/common/ai-credit-bar.scss"

register_asset "stylesheets/modules/ai-bot/common/ai-tools.scss"

register_asset "stylesheets/modules/ai-bot/common/ai-artifact.scss"

module ::DiscourseAi
  PLUGIN_NAME = "discourse-ai"

  def self.public_asset_path(name)
    File.expand_path(File.join(__dir__, "public", name))
  end
end

Rails.autoloaders.main.push_dir(File.join(__dir__, "lib"), namespace: DiscourseAi)

require_relative "lib/engine"
require_relative "lib/configuration/module"

DiscourseAi::Configuration::Module::NAMES.each do |module_name|
  register_site_setting_area("ai-features/#{module_name}")
end

after_initialize do
  if defined?(Rack::MiniProfiler)
    Rack::MiniProfiler.config.skip_paths << "/discourse-ai/ai-bot/artifacts"
  end

  # do not autoload this cause we may have no namespace
  require_relative "discourse_automation/llm_triage"
  require_relative "discourse_automation/llm_report"
  require_relative "discourse_automation/ai_tool_action"
  require_relative "discourse_automation/llm_persona_triage"
  require_relative "discourse_automation/llm_tagger"

  add_admin_route("discourse_ai.title", "discourse-ai", { use_new_show_route: true })

  register_seedfu_fixtures(Rails.root.join("plugins", "discourse-ai", "db", "fixtures", "personas"))

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

  on(:reviewable_transitioned_to) do |new_status, reviewable|
    ModelAccuracy.adjust_model_accuracy(new_status, reviewable)
    if DiscourseAi::AiModeration::SpamScanner.enabled?
      DiscourseAi::AiModeration::SpamMetric.update(new_status, reviewable)
    end
  end

  if Rails.env.test?
    require_relative "spec/support/embeddings_generation_stubs"
    require_relative "spec/support/stable_diffusion_stubs"
  end

  reloadable_patch do |plugin|
    Guardian.prepend DiscourseAi::GuardianExtensions
    Topic.prepend DiscourseAi::TopicExtensions
    Post.prepend DiscourseAi::PostExtensions
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

  add_api_key_scope(
    :discourse_ai,
    { update_personas: { actions: %w[discourse_ai/admin/ai_personas#update] } },
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
