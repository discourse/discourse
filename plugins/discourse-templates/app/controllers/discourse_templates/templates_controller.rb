# frozen_string_literal: true

module DiscourseTemplates
  class TemplatesController < ::ApplicationController
    requires_plugin DiscourseTemplates::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_discourse_templates_enabled
    skip_before_action :check_xhr

    def ensure_discourse_templates_enabled
      raise Discourse::InvalidAccess.new unless guardian.can_use_templates?
    end

    def use
      template_id = params.require(:id)
      topic = Topic.find_by(id: template_id)

      return render_json_error("Invalid template id", status: 422) if topic.blank?

      unless topic.template?(current_user)
        return(render_json_error("Id does not belong to a template", status: 422))
      end

      record = topic.increment_template_item_usage_count!

      render json: record
    end

    def index
      list_options = {
        # limit defined in a hidden setting with a sane default value (1000) that should be enough to fetch all
        # templates at once in most cases, but it still small enough to prevent things to blow up if the user
        # selected the wrong category in settings with thousands and thousands of posts
        per_page: SiteSetting.discourse_templates_max_replies_fetched.to_i,
      }

      topic_query = TopicQuery.new(current_user, list_options)
      category_templates = topic_query.list_category_templates&.topics || []
      private_templates = topic_query.list_private_templates&.topics || []

      templates = category_templates + private_templates

      render json: templates, each_serializer: TemplatesSerializer
    end
  end
end
