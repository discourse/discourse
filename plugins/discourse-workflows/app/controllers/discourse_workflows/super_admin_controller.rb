# frozen_string_literal: true

module DiscourseWorkflows
  class SuperAdminController < ::SuperAdmin::SuperAdminController
    requires_plugin DiscourseWorkflows::PLUGIN_NAME

    def index
      render html: "", layout: "admin"
    end
  end
end
