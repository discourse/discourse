class Admin::PluginsController < Admin::AdminController

  def index
    # json = Discourse.plugins.map(&:metadata)
    render_serialized(Discourse.plugins, AdminPluginSerializer)
  end

end
