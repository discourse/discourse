# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminAiFeatures < PageObjects::Pages::Base
      FEATURES_PAGE = ".ai-features"

      def visit
        page.visit("/admin/plugins/discourse-ai/ai-features")
        self
      end

      def toggle_enabled
        filter_by_status("enabled")
      end

      def toggle_not_enabled
        filter_by_status("not enabled")
      end

      def expand_module(module_name)
        module_row(module_name).find(".ai-features-module-row__expand").click
        self
      end

      def toggle_module(module_name)
        module_toggle(module_name).toggle
        self
      end

      def toggle_feature(feature_name)
        feature_toggle(feature_name).toggle
        self
      end

      def has_module_enabled?(module_name)
        module_toggle(module_name).checked?
      end

      def has_module_disabled?(module_name)
        module_toggle(module_name).unchecked?
      end

      def has_feature_enabled?(feature_name)
        feature_toggle(feature_name).checked?
      end

      def has_feature_disabled?(feature_name)
        feature_toggle(feature_name).unchecked?
      end

      def has_no_feature_toggle?(feature_name)
        page.has_css?(feature_row_selector(feature_name)) &&
          page.has_no_css?(
            "#{feature_row_selector(feature_name)} .ai-feature-setting-toggle",
            visible: :all,
          )
      end

      def has_listed_modules?(count)
        page.has_css?("#{FEATURES_PAGE} .ai-features-module-row", count: count)
      end

      def has_feature_agent?(feature_name, name)
        page.has_css?(
          "#{feature_row_selector(feature_name)} .ai-features-feature-row__agent-link",
          text: name,
        )
      end

      def has_feature?(feature_name, name)
        page.has_css?(
          "#{feature_row_selector(feature_name)} .ai-features-feature-row__name",
          text: name,
        )
      end

      def has_no_feature?(feature_name)
        page.has_no_css?(feature_row_selector(feature_name))
      end

      def has_feature_groups?(feature_name, groups)
        listed_groups =
          page.find("#{feature_row_selector(feature_name)} .ai-features-feature-row__group-list")
        list_items = listed_groups.all("li", visible: true).map(&:text)

        list_items.sort == groups.sort
      end

      def has_feature_decision_model?(feature_name, decision_model)
        page.find(feature_row_selector(feature_name)).has_link?(
          decision_model.display_name,
          href: "/admin/plugins/discourse-ai/ai-decision-models/#{decision_model.id}/edit",
        )
      end

      def has_no_feature_groups?(feature_name)
        page.has_css?(feature_row_selector(feature_name)) &&
          page.has_no_css?("#{feature_row_selector(feature_name)} .ai-features-feature-row__groups")
      end

      def has_dedicated_configuration_link?
        page.has_link?(
          href: "/admin/site_settings/category/all_results?filter=ai_sentiment_model_configs",
        )
      end

      def click_set_up_module(module_name)
        module_row(module_name).find(".edit", text: I18n.t("js.discourse_ai.features.set_up")).click
      end

      def has_module_status?(module_name, enabled:)
        module_row(module_name).has_css?(
          ".ai-features-status[data-status='#{enabled ? "on" : "off"}']",
        )
      end

      def click_edit_module(module_name)
        module_row(module_name).find(".edit").click
      end

      private

      def filter_by_status(status)
        page.find("#{FEATURES_PAGE} .ai-features__status-option[data-status='#{status}']").click
      end

      def module_toggle(module_name)
        PageObjects::Components::DToggleSwitch.new(
          "#{module_row_selector(module_name)} .ai-feature-setting-toggle",
        )
      end

      def feature_toggle(feature_name)
        PageObjects::Components::DToggleSwitch.new(
          "#{feature_row_selector(feature_name)} .ai-feature-setting-toggle",
        )
      end

      def module_row(module_name)
        page.find(module_row_selector(module_name))
      end

      def module_row_selector(module_name)
        "#{FEATURES_PAGE} .ai-features-module-row[data-module-name='#{module_name}']"
      end

      def feature_row_selector(feature_name)
        "#{FEATURES_PAGE} .ai-features-feature-row[data-feature-name='#{feature_name}']"
      end
    end
  end
end
