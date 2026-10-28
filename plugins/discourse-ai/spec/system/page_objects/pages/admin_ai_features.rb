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
        select = page.find("#{FEATURES_PAGE} .ai-features__controls .d-native-select")
        select.find("option[value='enabled']").select_option
      end

      def toggle_not_enabled
        select = page.find("#{FEATURES_PAGE} .ai-features__controls .d-native-select")
        select.find("option[value='not enabled']").select_option
      end

      def has_listed_modules?(count)
        page.has_css?("#{FEATURES_PAGE} .ai-module", count: count)
      end

      def has_feature_agent?(feature_name, name)
        page.has_css?(
          "#{FEATURES_PAGE} .ai-feature-card[data-feature-name='#{feature_name}'] .ai-feature-card__agent-link",
          text: name,
        )
      end

      def has_feature?(feature_name, name)
        page.has_css?(
          "#{FEATURES_PAGE} .ai-feature-card[data-feature-name='#{feature_name}'] .ai-feature-card__feature-name",
          text: name,
        )
      end

      def has_no_feature?(feature_name)
        page.has_no_css?("#{FEATURES_PAGE} .ai-feature-card[data-feature-name='#{feature_name}']")
      end

      def has_feature_groups?(feature_name, groups)
        listed_groups =
          page.find(
            "#{FEATURES_PAGE} .ai-feature-card[data-feature-name='#{feature_name}'] .ai-feature-card__item-groups",
          )
        list_items = listed_groups.all("li", visible: true).map(&:text)

        list_items.sort == groups.sort
      end

      def has_feature_decision_model?(feature_name, decision_model)
        page.find(
          "#{FEATURES_PAGE} .ai-feature-card[data-feature-name='#{feature_name}']",
        ).has_link?(
          decision_model.display_name,
          href: "/admin/plugins/discourse-ai/ai-decision-models/#{decision_model.id}/edit",
        )
      end

      def has_no_feature_groups?(feature_name)
        page.has_no_css?(
          "#{FEATURES_PAGE} .ai-feature-card[data-feature-name='#{feature_name}'] .ai-feature-card__groups",
        )
      end

      def has_dedicated_configuration_link?
        page.has_link?(
          href: "/admin/site_settings/category/all_results?filter=ai_sentiment_model_configs",
        )
      end

      def click_edit_module(module_name)
        page.find("#{FEATURES_PAGE} .ai-module[data-module-name='#{module_name}'] .edit").click
      end
    end
  end
end
