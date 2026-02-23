# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminHouseAds < PageObjects::Pages::Base
      def visit_page
        page.visit "/admin/plugins/discourse-adplugin/house-ads"
        self
      end

      def visit_new
        page.visit "/admin/plugins/discourse-adplugin/house-ads/new"
        self
      end

      def click_new_ad
        find(".d-page-subheader__actions .btn-primary").click
        self
      end

      def click_back
        find("a.back-button").click
        self
      end

      def click_ad(name)
        find(".house-ads-table tr.d-admin-row__content", text: name).find(
          ".house-ads-table__edit",
        ).click
        self
      end

      def has_ad_listed?(name)
        has_css?(".house-ads-table tr.d-admin-row__content", text: name)
      end

      def has_no_ad_listed?(name)
        has_no_css?(".house-ads-table tr.d-admin-row__content", text: name)
      end

      def click_delete
        find(".house-ad-form .btn-danger").click
        self
      end

      def has_empty_state?
        has_css?(".admin-config-area-empty-list")
      end
    end
  end
end
