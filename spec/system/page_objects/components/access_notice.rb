# frozen_string_literal: true

module PageObjects
  module Components
    class AccessNotice < PageObjects::Components::Base
      SELF_ONLY = ".access-notice.--self"
      STAFF_ONLY = ".access-notice.--staff"

      def initialize(context = nil)
        @context = context
      end

      def has_self_only?(**options)
        page.has_css?(selector(SELF_ONLY), **options)
      end

      def has_no_self_only?
        page.has_no_css?(selector(SELF_ONLY))
      end

      def has_staff_only?(**options)
        page.has_css?(selector(STAFF_ONLY), **options)
      end

      def has_no_staff_only?
        page.has_no_css?(selector(STAFF_ONLY))
      end

      private

      def selector(notice)
        [@context, notice].compact.join(" ")
      end
    end
  end
end
