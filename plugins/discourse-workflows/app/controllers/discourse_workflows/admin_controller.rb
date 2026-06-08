# frozen_string_literal: true

module DiscourseWorkflows
  class AdminController < ::Admin::AdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      render html: "", layout: "admin"
    end
  end
end
