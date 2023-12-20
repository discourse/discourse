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
      MultiJson.dump(Discourse.visible_plugins.filter(&:enabled?).map(&:admin_route).compact),
    )
  end
end
