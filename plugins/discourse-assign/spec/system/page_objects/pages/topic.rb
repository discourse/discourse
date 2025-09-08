# frozen_string_literal: true

module PageObjects
  module Pages
    class Topic < PageObjects::Pages::Base
      def click_assign_topic
        find("#topic-footer-button-assign").click
      end

      def click_unassign_topic
        find("#topic-footer-dropdown-reassign").click
        find("[data-value='unassign']").click
      end

      def click_unassign_post(post)
        find("#topic-footer-dropdown-reassign").click
        data_value = "unassign-from-post-#{post.id}"
        find("[data-value=\"#{data_value}\"]").click
      end

      def click_assign_post(post)
        find_post_action_button(post, :show_more).click
        assign_post = within_post(post) { find(".post-action-menu__assign-post") }
        assign_post.click
      end

      def click_edit_topic_assignment
        find("#topic-footer-dropdown-reassign").click
        find("[data-value='reassign']").click
      end

      def find_post_assign(post_number)
        within("#post_#{post_number}") { find(".assigned-to") }
      end

      def has_assigned?(args)
        has_assignment_action?(action: "assigned", **args)
      end

      def has_assigned_post?(args)
        has_assignment_action?(action: "assigned_to_post", **args)
      end

      def has_unassigned?(args)
        has_assignment_action?(action: "unassigned", **args)
      end

      def has_unassigned_from_post?(args)
        has_assignment_action?(action: "unassigned_from_post", **args)
      end

      def has_assignment_action?(args)
        assignee = args[:group]&.name || args[:user]&.username

        container =
          args[:at_post] ? find("#post_#{args[:at_post]}#{args[:class_attribute] || ""}") : page

        post_content =
          I18n.t(
            "js.action_codes.#{args[:action]}",
            path: "",
            who: "@#{assignee}",
            when: "just now",
          )

        if args[:action] == "assigned_to_post" || args[:action] == "unassigned_from_post"
          post_content.gsub!(%r{<a[^>]*>(.*?)</a>}, '\1')
        end

        container.has_content?(:all, post_content)
      end
    end
  end
end
