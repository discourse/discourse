# frozen_string_literal: true

# name: discourse-templates
# about: Allows the creation of content templates for repeated use.
# meta_topic_id: 229250
# version: 2.5.0
# authors: Discourse (discourse-templates), Jay Pfaffman and André Pereira (canned-replies)
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-templates

enabled_site_setting :discourse_templates_enabled

register_asset "stylesheets/discourse-templates.scss"

register_svg_icon "far-clipboard"

module ::DiscourseTemplates
  PLUGIN_NAME = "discourse-templates"
end

require_relative "lib/discourse_templates/engine"

after_initialize do
  require_relative "app/controllers/discourse_templates/templates_controller"
  require_relative "app/models/discourse_templates/usage_count"
  require_relative "app/serializers/discourse_templates/templates_serializer"
  require_relative "lib/discourse_templates/guardian_extension"
  require_relative "lib/discourse_templates/topic_extension"
  require_relative "lib/discourse_templates/topic_query_extension"
  require_relative "lib/discourse_templates/user_extension"

  Discourse::Application.routes.append do
    mount DiscourseTemplates::Engine, at: "/discourse_templates"
  end

  reloadable_patch do |plugin|
    Guardian.prepend(DiscourseTemplates::GuardianExtension)
    Topic.prepend(DiscourseTemplates::TopicExtension)
    TopicQuery.prepend(DiscourseTemplates::TopicQueryExtension)
    User.prepend(DiscourseTemplates::UserExtension)
  end

  add_to_serializer(:current_user, :can_use_templates) { object.can_use_templates? }

  add_to_serializer(
    :topic_view,
    :is_template,
    include_condition: -> { object.topic.template?(scope.user) },
  ) { true }
end
