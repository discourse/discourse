# frozen_string_literal: true

module PageObjects
  module Components
    class DsaClassification < PageObjects::Components::Base
      def select_rule(ground)
        within(".dsa-classification") { select(ground, from: "Community rule") }
      end

      def select_category(category)
        within(".dsa-classification") { select(category, from: "Category") }
      end

      def save
        within(".dsa-classification") { click_button("Save classification") }
      end

      def has_selected_rule?(ground)
        within(".dsa-classification") { has_select?("Community rule", selected: ground) }
      end

      def has_selected_category?(category)
        within(".dsa-classification") { has_select?("Category", selected: category) }
      end

      def has_no_sidebar?
        has_no_css?(".dsa-classification")
      end
    end
  end
end
