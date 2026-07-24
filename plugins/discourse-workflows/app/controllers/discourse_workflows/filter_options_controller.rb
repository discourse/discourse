# frozen_string_literal: true

module DiscourseWorkflows
  class FilterOptionsController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def posts
      render json: { filter_option_info: PostsFilter.option_info(guardian) }
    end
  end
end
