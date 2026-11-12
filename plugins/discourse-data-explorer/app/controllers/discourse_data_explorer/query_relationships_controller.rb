# frozen_string_literal: true

module DiscourseDataExplorer
  class QueryRelationshipsController < JsonApiKit::RelationshipsController
    requires_plugin PLUGIN_NAME

    before_action :ensure_admin

    resource :queries
  end
end
