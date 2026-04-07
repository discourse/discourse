# frozen_string_literal: true

module DiscourseWorkflows
  class HmacSigner
    def self.sign(payload)
      OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, payload)
    end

    def self.verify(payload, signature)
      ActiveSupport::SecurityUtils.secure_compare(sign(payload), signature)
    end
  end
end
