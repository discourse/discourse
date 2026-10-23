# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminLeaderboards < PageObjects::Pages::Base
      def new_form
        @new_form ||= PageObjects::Components::FormKit.new(".new-leaderboard-form")
      end

      def full_form
        @full_form ||= PageObjects::Components::FormKit.new(".edit-create-leaderboard-form")
      end

      def select_included_groups(*groups)
        included_groups_sk =
          PageObjects::Components::SelectKit.new("#leaderboard-edit__included-groups")
        included_groups_sk.expand
        groups.each { |g| included_groups_sk.select_row_by_name(g) }
        included_groups_sk.collapse
      end

      def select_excluded_groups(*groups)
        excluded_groups_sk =
          PageObjects::Components::SelectKit.new("#leaderboard-edit__excluded-groups")
        excluded_groups_sk.expand
        groups.each { |g| excluded_groups_sk.select_row_by_name(g) }
        excluded_groups_sk.collapse
      end

      def click_creator(leaderboard)
        find("#leaderboard-admin__row-#{leaderboard.id} .leaderboard-admin__creator-link").click
        self
      end

      def edit_leaderboard(leaderboard)
        find("#leaderboard-admin__row-#{leaderboard.id} .leaderboard-admin__edit").click
      end

      def click_leaderboard_name(leaderboard)
        find("#leaderboard-admin__row-#{leaderboard.id} .d-table__overview-link").click
      end

      def view_leaderboard(leaderboard)
        row_menu(leaderboard).option(".leaderboard-admin__view").click
      end

      def delete_leaderboard(leaderboard)
        row_menu(leaderboard).option(".leaderboard-admin__delete").click
      end

      private

      def row_menu(leaderboard)
        menu =
          PageObjects::Components::DMenu.new(
            "#leaderboard-admin__row-#{leaderboard.id} .leaderboard-admin-menu-trigger",
            "leaderboard-admin-menu",
          )
        menu.expand
        menu
      end
    end
  end
end
