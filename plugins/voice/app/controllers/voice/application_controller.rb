# frozen_string_literal: true

module Voice
  class ApplicationController < ::ApplicationController
    requires_plugin ::Voice::PLUGIN_NAME

    before_action :ensure_logged_in
    before_action :ensure_enabled!

    private

    def ensure_enabled!
      raise Discourse::InvalidAccess.new(I18n.t("voice.errors.not_enabled")) unless Voice.enabled?
    end
  end
end
