# frozen_string_literal: true

module JsonApiKit
  class BaseController
    module RequestInput
      extend ActiveSupport::Concern

      delegate :query, :body, to: :request_inputs, prefix: :request, private: true

      private

      def service_params = { params: request_body.parameters, guardian: }

      def request_inputs
        @request_inputs ||= Request::Inputs.new(request, resource: request_resource)
      end

      def request_resource = @request_resource ||= resource.new(guardian:, edition:)
    end
  end
end
