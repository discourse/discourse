# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminTagGroups < PageObjects::Pages::Base
      def tags_chooser
        PageObjects::Components::SelectKit.new(".group-tags-list .tag-chooser")
      end

      def parent_tag_chooser
        PageObjects::Components::SelectKit.new(".parent-tag-section .tag-chooser")
      end

      def has_tag_group_in_sidebar?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).matches?(
          browser_root.locator(".tag-groups-sidebar li").filter(visible: true),
        )
      end

      def has_no_tag_group_in_sidebar?(name)
        contain_text([browser_text_pattern(name)], useInnerText: true).does_not_match?(
          browser_root.locator(".tag-groups-sidebar li").filter(visible: true),
        )
      end

      def has_tags_label?
        contain_text(
          [browser_text_pattern(I18n.t("js.tagging.groups.tags_label"))],
          useInnerText: true,
        ).matches?(browser_root.locator(".group-tags-list label").filter(visible: true))
      end

      def has_parent_tag_label?
        contain_text(
          [browser_text_pattern(I18n.t("js.tagging.groups.parent_tag_label"))],
          useInnerText: true,
        ).matches?(browser_root.locator(".parent-tag-section label").filter(visible: true))
      end

      def has_visible_permission_label?
        contain_text(
          [browser_text_pattern(I18n.t("js.tagging.groups.usable_only_by_groups"))],
          useInnerText: true,
        ).matches?(browser_root.locator("label[for='visible-permission']").filter(visible: true))
      end

      def has_name?(name)
        within_browser(browser_root.locator(".group-name").filter(visible: true)) do
          have_value(name).matches?(
            browser_root.locator(
              "input:not(:disabled), textarea:not(:disabled), select:not(:disabled)",
            ).filter(visible: true),
          )
        end
      end

      def has_tag_in_group?(tag_name)
        contain_text([browser_text_pattern(tag_name)], useInnerText: true).matches?(
          browser_root.locator(".group-tags-list .tag-chooser").filter(visible: true),
        )
      end

      def has_no_tag_in_group?(tag_name)
        contain_text([browser_text_pattern(tag_name)], useInnerText: true).does_not_match?(
          browser_root.locator(".group-tags-list .tag-chooser").filter(visible: true),
        )
      end

      def visit
        browser_page.goto("/tag_groups").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def visit_tag_group(tag_group)
        browser_page
          .goto("/tag_groups/#{tag_group.id}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def click_new_tag_group
        if browser_root.locator(".tag-groups-sidebar .btn-default").filter(visible: true).count != 0
          browser_root.locator(".tag-groups-sidebar .btn-default").filter(visible: true).click
        else
          browser_root.locator(".tag-group-content .btn-primary").filter(visible: true).click
        end
        self
      end

      def fill_name(name)
        browser_root.locator(".group-name input").filter(visible: true).fill(name)
        self
      end

      def select_public_permission
        browser_root.locator("#public-permission").filter(visible: true).click
        self
      end

      def select_visible_permission
        browser_root.locator("#visible-permission").filter(visible: true).click
        self
      end

      def has_visible_permission_checked?
        browser_root.locator("#visible-permission").filter(visible: true).checked?
      end

      def has_private_permission_checked?
        browser_root.locator("#private-permission").filter(visible: true).checked?
      end

      def has_public_permission_checked?
        browser_root.locator("#public-permission").filter(visible: true).checked?
      end

      def has_private_group?(group_name)
        contain_text([browser_text_pattern(group_name)], useInnerText: true).matches?(
          browser_root.locator(
            ".group-visibility-option:has(#private-permission) .group-chooser",
          ).filter(visible: true),
        )
      end

      def private_group_chooser
        PageObjects::Components::SelectKit.new(
          ".group-visibility-option:has(#private-permission) .group-chooser",
        )
      end

      def save
        browser_root.locator(".tag-group-controls .btn-primary").filter(visible: true).click
        self
      end

      def click_delete
        browser_root.locator(".tag-group-controls .btn-danger").filter(visible: true).click
        PageObjects::Components::Dialog.new
      end

      def click_tag_group(name)
        browser_root
          .locator(".tag-groups-sidebar li a")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(name))
          .click
        self
      end
    end
  end
end
