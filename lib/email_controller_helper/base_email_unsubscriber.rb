# frozen_string_literal: true

# This class and its children are instantiated and used by the EmailController.
module EmailControllerHelper
  class BaseEmailUnsubscriber
    def initialize(unsubscribe_key)
      @unsubscribe_key = unsubscribe_key
    end

    attr_reader :unsubscribe_key

    # Sets instance variables in the `EmailController#unsubscribe`, which are later available in the view.
    # Don't forget to call super when extending this method.
    def prepare_unsubscribe_options(controller)
      controller.instance_variable_set(:@digest_unsubscribe, false)
      controller.instance_variable_set(:@watched_count, nil)
      controller.instance_variable_set(:@type, unsubscribe_key.unsubscribe_key_type)

      controller.instance_variable_set(:@user, key_owner)

      controller.instance_variable_set(
        :@unsubscribed_from_all,
        key_owner.user_option.unsubscribed_from_all?,
      )
    end

    # Called by the `EmailController#perform_unsubscribe` and defines what unsubscribing means.
    #
    # Receives the request params and returns a boolean indicating if any preferences were updated.
    #
    # Don't forget to call super when extending this method.
    def unsubscribe(params)
      updated = false

      if params[:disable_mailing_list]
        key_owner.user_option.update_columns(mailing_list_mode: false)
        updated = true
      end

      if params[:unsubscribe_all]
        key_owner.user_option.update_columns(
          email_digests: false,
          email_level: UserOption.email_level_types[:never],
          email_messages_level: UserOption.email_level_types[:never],
          mailing_list_mode: false,
        )
        updated = true
      end

      updated
    end

    protected

    def key_owner
      unsubscribe_key.user
    end
  end
end
