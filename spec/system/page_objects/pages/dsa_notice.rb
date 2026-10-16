# frozen_string_literal: true

module PageObjects
  module Pages
    class DsaNotice < Base
      def form
        PageObjects::Components::FormKit.new(".dsa-notice .form-kit")
      end

      def has_notice_form?
        has_css?(".dsa-notice .form-kit")
      end

      def has_no_notice_form?
        has_no_css?(".dsa-notice .form-kit")
      end

      def has_confirmation?
        has_css?(".dsa-notice h1", text: "Notice received")
      end

      def has_focused_confirmation?
        has_css?(".dsa-notice h1:focus", text: "Notice received")
      end

      def reference
        find(".dsa-notice__reference strong").text
      end

      def explanation
        "This listing advertises counterfeit goods as authentic and asks buyers to pay outside the marketplace. The product description and payment instructions appear intended to deceive buyers."
      end

      def fill_notice
        form.field("explanation").fill_in(explanation)
      end

      def open_group_notice(user:, group:, reference:)
        visit("/u/#{user.username}/messages/group/#{group.name}")
        click_link(I18n.t("dsa_notice.subject", reference:))
        expect(page).to have_css(".cooked", text: reference)
      end
    end
  end
end
