# frozen_string_literal: true

# name: discourse-shared-edits
# about: Allows multiple users to collaboratively edit posts in real time.
# meta_topic_id: 167583
# version: 0.1.0
# authors: Sam Saffron
# url: https://github.com/discourse/discourse-shared-edits

enabled_site_setting :shared_edits_enabled

register_asset "stylesheets/common/discourse-shared-edits.scss"
register_asset "stylesheets/yjs-cursors.scss"

after_initialize do
  module ::DiscourseSharedEdits
    SHARED_EDITS_ENABLED = "shared_edits_enabled"
    PLUGIN_NAME = "discourse-shared-edits"

    class Engine < ::Rails::Engine
      engine_name PLUGIN_NAME
      isolate_namespace ::DiscourseSharedEdits
    end
  end

  require_relative "lib/yjs_text_operations"
  require_relative "app/models/shared_edit_revision"
  require_relative "app/controllers/discourse_shared_edits/revision_controller"
  require_relative "app/jobs/commit_shared_revision"
  require_relative "lib/discourse_shared_edits/guardian_extension"

  ::DiscourseSharedEdits::Engine.routes.draw do
    put "/p/:post_id/enable" => "revision#enable"
    put "/p/:post_id/disable" => "revision#disable"
    put "/p/:post_id" => "revision#revise"
    get "/p/:post_id" => "revision#latest"
    put "/p/:post_id/commit" => "revision#commit"
  end

  Discourse::Application.routes.append { mount ::DiscourseSharedEdits::Engine, at: "/shared_edits" }

  reloadable_patch { Guardian.prepend(DiscourseSharedEdits::GuardianExtension) }

  register_post_custom_field_type(DiscourseSharedEdits::SHARED_EDITS_ENABLED, :boolean)
  topic_view_post_custom_fields_allowlister { [DiscourseSharedEdits::SHARED_EDITS_ENABLED] }

  add_to_serializer(:post, :shared_edits_enabled) do
    if SiteSetting.shared_edits_enabled
      post_custom_fields[DiscourseSharedEdits::SHARED_EDITS_ENABLED]
    end
  end
end
