# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiThemeTranslationsController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def create
        theme = Theme.find_by(id: params[:theme_id])
        raise Discourse::NotFound if theme.blank?

        Jobs.enqueue(:localize_theme_translations, theme_id: theme.id)

        head :no_content
      end
    end
  end
end
