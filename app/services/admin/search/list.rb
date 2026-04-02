# frozen_string_literal: true

module Admin
  module Search
    class List
      include Service::Base

      RESULT_FILTER_STATUSES = %w[experimental alpha beta stable].freeze

      params do
        attribute :filter_names, :array
        attribute :filter_area, :string
        attribute :plugin, :string
        attribute :categories, :array

        def include_locale_setting?
          filter_area.blank? || filter_area == "localization"
        end
      end

      policy :current_user_is_admin
      model :settings
      model :themes_and_components
      model :reports
      model :upcoming_changes

      private

      def current_user_is_admin(guardian:)
        guardian.is_admin?
      end

      def fetch_settings(params:)
        SiteSetting.all_settings(
          filter_names: params.filter_names,
          filter_area: params.filter_area,
          filter_plugin: params.plugin,
          filter_categories: params.categories,
          include_locale_setting: params.include_locale_setting?,
          basic_attributes: true,
        )
      end

      def fetch_themes_and_components(guardian:)
        Theme.all.order(:name).to_a
      end

      def fetch_reports(guardian:)
        Reports::ListQuery.call(admin: true)
      end

      def fetch_upcoming_changes(guardian:)
        UpcomingChanges::List.call(
          guardian:,
          options: {
            filter_statuses: RESULT_FILTER_STATUSES,
          },
        ).upcoming_changes
      end
    end
  end
end
