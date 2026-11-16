# frozen_string_literal: true

module DiscourseAi
  module Decisions
    module Endpoints
      class Typesafe < SystemOne
        def payload(state:, questions:, images:)
          payload = super(state:, questions:, images: [])
          if images.present?
            payload[:assets] = images.to_h do |image|
              match = image.match(%r{\Adata:image/(png|jpeg|jpg);base64,(.+)\z})
              raise InvalidRequest, "Images must be PNG or JPEG base64 data URLs" if !match

              format = match[1] == "jpg" ? "jpeg" : match[1]
              [SecureRandom.uuid, { type: "image", format:, data_base64: match[2] }]
            end
            # Every asset must be referenced without changing the original state.
            payload[:state] = { text: state, images: payload[:assets].keys }
          end
          payload
        end

        def audit_payload(payload)
          payload = payload.deep_dup
          payload[:assets]&.each_value do |asset|
            asset[:data_base64] = redacted_image(
              asset[:data_base64],
              mime_type: "image/#{asset[:format]}",
            )
          end
          payload
        end
      end
    end
  end
end
