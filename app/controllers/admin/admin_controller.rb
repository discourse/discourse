# frozen_string_literal: true

class Admin::AdminController < ApplicationController
  requires_login
  before_action :ensure_admin

  def index
    render body: nil
  end

  private

  def preload_additional_json
    store_preloaded(
      "enabledPluginAdminRoutes",
      MultiJson.dump(Discourse.plugins_sorted_by_name.map(&:admin_route).compact),
    )
  end
end
