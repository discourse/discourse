# frozen_string_literal: true

module ::Lovelace
  class ChecklistsController < ::ApplicationController
    requires_plugin PLUGIN_NAME
    requires_login
    before_action :ensure_admin

    def show
      render json: Checklist.read
    end

    def update
      raw_items = params[:items]
      raise Discourse::InvalidParameters.new(:items) unless raw_items.is_a?(Array)
      items =
        Checklist.normalize(
          raw_items.map { |item| item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h : item },
        )
      DistributedMutex.synchronize("lovelace-checklist") do
        current = Checklist.read
        if params[:revision].to_s != current["revision"].to_s
          return render json: { errors: [I18n.t("lovelace.checklist_conflict")] }, status: :conflict
        end
        result = { "items" => items, "revision" => current["revision"] + 1 }
        PluginStore.set(PLUGIN_NAME, "checklist", result)
        render json: result
      end
    end
  end
end
