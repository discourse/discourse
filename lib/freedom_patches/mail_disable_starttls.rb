# frozen_string_literal: true

# Patch from
# https://github.com/rails/rails/issues/44698#issuecomment-1069675285 to enable
# previous behavior with Net::SMTP regarding TLS.
#
# This should be fixed in an upcoming release of the Mail gem (probably 2.8),
# when this patch is merged: https://github.com/mikel/mail/pull/1435
module FreedomPatches
  module MailDisableStarttls
    def build_smtp_session
      super.tap do |smtp|
        unless settings[:enable_starttls_auto]
          smtp.disable_starttls if smtp.respond_to?(:disable_starttls)
        end
      end
    end

    ::Mail::SMTP.prepend(self)
  end
end
