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
        has_css?(".tag-groups-sidebar li", text: name)
      end

      def has_no_tag_group_in_sidebar?(name)
        has_no_css?(".tag-groups-sidebar li", text: name)
      end

      def has_tags_label?
        has_css?(".group-tags-list label", text: I18n.t("js.tagging.groups.tags_label"))
      end

      def has_parent_tag_label?
        has_css?(".parent-tag-section label", text: I18n.t("js.tagging.groups.parent_tag_label"))
      end

      def has_visible_permission_label?
        has_css?(
          "label[for='visible-permission']",
          text: I18n.t("js.tagging.groups.usable_only_by_groups"),
        )
      end

      def has_tag_in_group?(tag_name)
        has_css?(".group-tags-list .tag-chooser", text: tag_name)
      end

      def has_no_tag_in_group?(tag_name)
        has_no_css?(".group-tags-list .tag-chooser", text: tag_name)
      end

      def visit
        page.visit("/tag_groups")
        self
      end

      def visit_tag_group(tag_group)
        page.visit("/tag_groups/#{tag_group.id}")
        self
      end

      def click_new_tag_group
        if has_css?(".tag-groups-sidebar .btn-default", wait: 0)
          find(".tag-groups-sidebar .btn-default").click
        else
          find(".tag-group-content .btn-primary").click
        end
        self
      end

      def fill_name(name)
        find(".group-name input").fill_in(with: name)
        self
      end

      def select_public_permission
        find("#public-permission").click
        self
      end

      def select_visible_permission
        find("#visible-permission").click
        self
      end

      def has_visible_permission_checked?
        find("#visible-permission").checked?
      end

      def save
        find(".tag-group-controls .btn-primary").click
        self
      end

      def click_delete
        find(".tag-group-controls .btn-danger").click
        PageObjects::Components::Dialog.new
      end

      def click_tag_group(name)
        find(".tag-groups-sidebar li", text: name).click
        self
      end
    end
  end
end
