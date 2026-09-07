# frozen_string_literal: true

module DiscourseDataExplorer
  class QueriesController < JsonApiKit::BaseController
    requires_plugin PLUGIN_NAME

    before_action :ensure_admin

    resource :queries
  end
end
