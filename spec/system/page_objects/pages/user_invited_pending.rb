# frozen_string_literal: true

module PageObjects
  module Pages
    class UserInvitedPending < PageObjects::Pages::Base
      class Invite
        attr_reader :tr_element

        def initialize(tr_element)
          @tr_element = tr_element
        end

        def link_type?(key: nil, redemption_count: nil, max_redemption_count: nil)
          if key && redemption_count && max_redemption_count
            invite_type_col.has_text?(
              I18n.t(
                "js.user.invited.invited_via_link",
                key: "#{key[0...4]}...",
                count: redemption_count,
                max: max_redemption_count,
              ),
            )
          else
            invite_type_col.has_css?(".d-icon-link")
          end
        end

        def email_type?(email)
          invite_type_col.has_text?(email) && invite_type_col.has_css?(".d-icon-envelope")
        end

        def has_group?(group)
          invite_type_col.has_css?(".invite-extra", text: group.name)
        end

        def has_topic?(topic)
          invite_type_col.has_css?(".invite-extra", text: topic.title)
        end

        def edit_button
          tr_element.find(".invite-actions .btn-default")
        end

        def expiry_date
          Time.parse(tr_element.find(".invite-expires-at").text).utc
        end

        private

        def invite_type_col
          tr_element.find(".invite-type")
        end
      end

      def visit(user)
        url = "/u/#{user.username_lower}/invited/pending"
        page.visit(url)
      end

      def invite_button
        find("#user-content .invite-button")
      end

      def invites_list
        all("#user-content .user-invite-list tbody tr").map { |row| Invite.new(row) }
      end

      def latest_invite
        Invite.new(find("#user-content .user-invite-list tbody tr:first-of-type"))
      end
    end
  end
end
