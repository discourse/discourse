# frozen_string_literal: true

module DiscourseAi
  module Admin
    class AiThemeTranslationsController < ::Admin::AdminController
      requires_plugin "discourse-ai"

      def create
        theme = Theme.find_by(id: params[:theme_id])
        raise Discourse::NotFound if theme.blank?

        locale = params[:locale].to_s
        source_locale = (locale.present? && LocaleSiteSetting.valid_value?(locale)) ? locale : "en"

        target_locales =
          SiteSetting.content_localization_supported_locales.to_s.split("|") - [source_locale]
        target_locales &= Array(params[:target_locales]) if params.key?(:target_locales)
        override_existing = ActiveModel::Type::Boolean.new.cast(params[:override_existing]) == true

        Jobs.enqueue(
          :localize_theme_translations,
          theme_id: theme.id,
          source_locale:,
          target_locales:,
          override_existing:,
        )

        head :no_content
      end
    end
  end
end
