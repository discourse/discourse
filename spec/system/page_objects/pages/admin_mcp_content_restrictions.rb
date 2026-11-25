# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminMcpContentRestrictions < PageObjects::Pages::Base
      def visit_page
        page.visit("/admin/config/mcp/content-restrictions")
        self
      end

      def toggle_private_messages
        page.find(".--private-messages .d-toggle-switch__label").click
        self
      end

      def has_private_messages_access?(accessible)
        page.has_css?(
          ".admin-mcp-content-restrictions__private-messages-toggle[aria-checked='#{accessible}']",
          visible: :all,
        )
      end

      def deny_tag(name)
        chooser =
          PageObjects::Components::SelectKit.new(
            ".--forum-content .form-kit__field[data-name='deny_tags'] .tag-chooser",
          )
        chooser.expand
        chooser.search(name)
        chooser.select_row_by_name(name)
        chooser.collapse
        self
      end

      def save_forum_rule
        page.find(".--forum-content .admin-mcp-content-restrictions__save").click
        self
      end

      def turn_off_forum_rule
        page.find(".--forum-content .admin-mcp-content-restrictions__turn-off").click
        self
      end

      def has_forum_rule_active?
        page.has_css?(".--forum-content .admin-mcp-content-restrictions__turn-off")
      end

      def has_no_forum_rule_active?
        page.has_no_css?(".--forum-content .admin-mcp-content-restrictions__turn-off")
      end

      def has_unknown_rule?(name)
        page.has_css?(".admin-mcp-content-restrictions__rule.--unknown", text: name)
      end

      def has_no_unknown_rule?(name)
        page.has_no_css?(".admin-mcp-content-restrictions__rule.--unknown", text: name)
      end

      def delete_unknown_rule(name)
        page
          .find(".admin-mcp-content-restrictions__rule.--unknown", text: name)
          .find(".admin-mcp-content-restrictions__delete")
          .click
        self
      end
    end
  end
end
