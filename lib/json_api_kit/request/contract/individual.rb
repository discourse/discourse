# frozen_string_literal: true

module JsonApiKit
  class Request
    class Contract
      class Individual < Contract
        include Fields
        include Including
        include Filtering

        private

        def check_filter_name(path)
          return super unless path.local?
          return if errors.of_kind?(:filter, :unknown_parameter)
          errors.add(:filter, :unknown_parameter, message: "unknown parameter")
        end
      end
    end
  end
end
