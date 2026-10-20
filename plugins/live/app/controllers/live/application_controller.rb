# frozen_string_literal: true

module Live
  class ApplicationController < ::ApplicationController
    requires_plugin ::Live::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_enabled!

    private

    def ensure_enabled!
      raise Discourse::InvalidAccess.new(I18n.t("live.errors.not_enabled")) unless Live.enabled?
    end
  end
end
