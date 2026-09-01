# frozen_string_literal: true

# name: discourse-zendesk-plugin
# about: Allows the creation of Zendesk tickets from Discourse topics.
# meta_topic_id: 68005
# version: 1.0.1
# authors: Yana Agun Siswanto, Arpit Jalan
# url: https://github.com/discourse/discourse/tree/main/plugins/discourse-zendesk-plugin

require "inflection"
require "net/http/post/multipart"
require "faraday/multipart"
require "zendesk_api"

enabled_site_setting :zendesk_enabled

register_svg_icon "headset"
register_svg_icon "clone"

module ::DiscourseZendeskPlugin
  PLUGIN_NAME = "discourse-zendesk-plugin"

  ZENDESK_ID_FIELD = "discourse_zendesk_plugin_zendesk_id"
  ZENDESK_URL_FIELD = "discourse_zendesk_plugin_zendesk_url"
  ZENDESK_API_URL_FIELD = "discourse_zendesk_plugin_zendesk_api_url"

  module GuardianExtension
    def can_create_zendesk_ticket?(topic)
      zendesk_ticket_accessible?(topic) &&
        in_any_groups?(SiteSetting.zendesk_create_ticket_allowed_groups_map)
    end

    def can_view_zendesk_ticket?(topic)
      return false if !zendesk_ticket_accessible?(topic)
      return false if topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD].blank?

      allowed_group_ids =
        SiteSetting.zendesk_create_ticket_allowed_groups_map |
          SiteSetting.zendesk_view_ticket_allowed_groups_map
      in_any_groups?(allowed_group_ids)
    end

    private

    def zendesk_ticket_accessible?(topic)
      authenticated? && SiteSetting.zendesk_enabled? && SiteSetting.zendesk_url.present? &&
        DiscourseZendeskPlugin::Helper.configured? && can_see?(topic)
    end
  end
end

require_relative "lib/discourse_zendesk_plugin/engine"
require_relative "lib/discourse_zendesk_plugin/helper"
require_relative "lib/discourse_zendesk_plugin/oauth_token"

after_initialize do
  require_relative "app/jobs/onceoff/migrate_zendesk_autogenerate_categories_site_settings"
  require_relative "app/jobs/regular/zendesk_job"
  require_relative "lib/discourse_zendesk_plugin/post_extension"
  require_relative "lib/discourse_zendesk_plugin/topic_extension"
  require_relative "app/services/problem_check/zendesk_api_token_deprecation"

  register_problem_check ProblemCheck::ZendeskApiTokenDeprecation

  Guardian.prepend DiscourseZendeskPlugin::GuardianExtension

  reloadable_patch do |plugin|
    Post.prepend DiscourseZendeskPlugin::PostExtension
    Topic.prepend DiscourseZendeskPlugin::TopicExtension
  end

  add_to_serializer(
    :topic_view,
    DiscourseZendeskPlugin::ZENDESK_ID_FIELD.to_sym,
    include_condition: -> { scope.can_view_zendesk_ticket?(object.topic) },
    respect_plugin_enabled: false,
  ) { object.topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD] }

  add_to_serializer(
    :topic_view,
    DiscourseZendeskPlugin::ZENDESK_URL_FIELD.to_sym,
    include_condition: -> { scope.can_view_zendesk_ticket?(object.topic) },
    respect_plugin_enabled: false,
  ) do
    id = object.topic.custom_fields[DiscourseZendeskPlugin::ZENDESK_ID_FIELD]
    uri = URI.parse(SiteSetting.zendesk_url)
    "#{uri.scheme}://#{uri.host}/agent/tickets/#{id}"
  end

  add_to_serializer(
    :topic_view,
    :can_create_zendesk_ticket,
    include_condition: -> { !is_a?(WebHookTopicViewSerializer) },
  ) { scope.can_create_zendesk_ticket?(object.topic) }

  add_to_serializer(
    :topic_view,
    :can_view_zendesk_ticket,
    include_condition: -> { !is_a?(WebHookTopicViewSerializer) },
  ) { scope.can_view_zendesk_ticket?(object.topic) }

  add_to_serializer(:current_user, :discourse_zendesk_plugin_status) do
    DiscourseZendeskPlugin::Helper.configured? && SiteSetting.zendesk_url
  end
end
