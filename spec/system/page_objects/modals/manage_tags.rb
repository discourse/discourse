# frozen_string_literal: true

module PageObjects
  module Modals
    class ManageTags < PageObjects::Modals::Base
      MODAL_SELECTOR = ".topic-bulk-actions-modal"
      ROOT_SELECTOR = ".manage-tags-form"

      def add_tag_selector
        tag_selector("[data-name='add_tags'] .tag-chooser")
      end

      def add_tags(*tag_names)
        select_tags(add_tag_selector, tag_names)
      end

      def remove_tags(*tag_names)
        select_tags(remove_tag_selector, tag_names)
      end

      def select_replace_from(tag_name, index: 0)
        select_tags(replace_from_selector(index), [tag_name])
      end

      def select_replace_to(tag_name, index: 0)
        select_tags(replace_to_selector(index), [tag_name])
      end

      def has_replace_row_error?(index: 0, text:)
        has_css?(
          "#{ROOT_SELECTOR} [data-name^='replace_rows.#{index}.'] .form-kit__errors",
          text: text,
        )
      end

      def has_no_replace_row_error?(index: 0)
        has_no_css?("#{ROOT_SELECTOR} [data-name^='replace_rows.#{index}.'] .form-kit__errors")
      end

      def toggle_remove_all
        PageObjects::Components::DToggleSwitch.new(
          "#{ROOT_SELECTOR} [data-name='remove_all_tags'] .d-toggle-switch__checkbox",
        ).toggle
      end

      def click_confirm
        find("#bulk-topics-confirm").click
      end

      def has_disabled_submit?
        has_css?("#bulk-topics-confirm[disabled]")
      end

      def has_remove_all_notice?
        has_css?("#{ROOT_SELECTOR} .manage-tags-form__warning")
      end

      def has_no_remove_tag_selector?
        has_no_css?("#{ROOT_SELECTOR} [data-name='remove_tags'] .tag-chooser")
      end

      private

      def tag_selector(scope)
        PageObjects::Components::SelectKit.new("#{ROOT_SELECTOR} #{scope}")
      end

      def remove_tag_selector
        tag_selector("[data-name='remove_tags'] .tag-chooser")
      end

      def replace_from_selector(index = 0)
        tag_selector("[data-name='replace_rows.#{index}.from'] .tag-chooser")
      end

      def replace_to_selector(index = 0)
        tag_selector("[data-name='replace_rows.#{index}.to'] .tag-chooser")
      end

      def select_tags(selector, tag_names)
        selector.expand
        tag_names.each do |name|
          selector.search(name)
          selector.select_row_by_name(name)
        end
        selector.collapse
      end
    end
  end
end
