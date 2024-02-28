# frozen_string_literal: true

module PageObjects
  module Modals
    class PrivateMessageInvite < PageObjects::Modals::Base
      MODAL_SELECTOR = ".add-pm-participants"
      BODY_SELECTOR = ".invite.modal-panel"

      # SELECTOR
      # class="select-kit multi-select user-chooser email-group-user-chooser full-width-wrap ember-view invite-user-input"
    end
  end
end
