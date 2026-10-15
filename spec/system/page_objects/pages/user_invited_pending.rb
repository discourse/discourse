# frozen_string_literal: true

module PageObjects
  module Pages
    class UserInvitedPending < PageObjects::Pages::Base
      class Invite
        include NativeSystemHelpers
        attr_reader :tr_element

        def initialize(tr_element)
          @tr_element = tr_element
        end

        def link_type?(key: nil, redemption_count: nil, max_redemption_count: nil)
          if key && redemption_count && max_redemption_count
            PlaywrightMatchers.contain_text(
              browser_text_pattern(
                I18n.t(
                  "js.user.invited.invited_via_link",
                  key: "#{key[0...4]}...",
                  count: redemption_count,
                  max: max_redemption_count,
                ),
              ),
              useInnerText: true,
            ).matches?(invite_type_col)
          else
            PlaywrightMatchers.have_count(0).does_not_match?(
              invite_type_col.locator(".d-icon-link").filter(visible: true),
            )
          end
        end

        def has_description?(text)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(text)],
            useInnerText: true,
          ).matches?(invite_type_col.locator(".invite-description").filter(visible: true))
        end

        def email_type?(email)
          PlaywrightMatchers.contain_text(browser_text_pattern(email), useInnerText: true).matches?(
            invite_type_col,
          ) &&
            PlaywrightMatchers.have_count(0).does_not_match?(
              invite_type_col.locator(".d-icon-envelope").filter(visible: true),
            )
        end

        def has_group?(group)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(group.name)],
            useInnerText: true,
          ).matches?(invite_type_col.locator(".invite-extra").filter(visible: true))
        end

        def has_topic?(topic)
          PlaywrightMatchers.contain_text(
            [browser_text_pattern(topic.title)],
            useInnerText: true,
          ).matches?(invite_type_col.locator(".invite-extra").filter(visible: true))
        end

        def edit_button
          tr_element.locator(".invite-actions .edit-invite").filter(visible: true)
        end

        def expiry_date
          Time.parse(
            tr_element.locator(".invite-expires-at").filter(visible: true).inner_text.strip,
          ).utc
        end

        def copy_link
          actions_menu.expand
          actions_menu.option(".copy-button").click
        end

        def has_link_copied?
          actions_menu.has_option?(".copy-button.ok")
        end

        private

        def invite_type_col
          tr_element.locator(".invite-type").filter(visible: true)
        end

        def actions_menu
          @actions_menu ||=
            PageObjects::Components::DMenu.new(
              tr_element.locator(
                ".invite-actions [data-trigger][data-identifier='invites-menu']",
              ).filter(visible: true),
              "invites-menu",
            )
        end
      end

      def visit(user)
        url = "/u/#{user.username_lower}/invited/pending"
        browser_page.goto(url).tap { SystemBrowserBootstrap.wait_for(browser_page) }
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".user-content.--loaded").filter(visible: true),
        )
      end

      def invite_button
        browser_root.locator(".user-content .invite-button").filter(visible: true)
      end

      def has_invite_count?(count)
        PlaywrightMatchers.have_count(count).matches?(
          browser_root.locator(".user-content .user-invite-list tbody tr").filter(visible: true),
        )
      end

      def invites_list
        browser_root
          .locator(".user-content .user-invite-list tbody tr")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |row| Invite.new(row) }
      end

      def latest_invite
        Invite.new(
          browser_root.locator(".user-content .user-invite-list tbody tr:first-of-type").filter(
            visible: true,
          ),
        )
      end

      def invite_row(invite)
        Invite.new(
          browser_root
            .locator(".user-content .user-invite-list tbody tr")
            .filter(visible: true)
            .filter(hasText: browser_text_pattern(invite.email)),
        )
      end
    end
  end
end
