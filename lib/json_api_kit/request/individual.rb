# frozen_string_literal: true

module JsonApiKit
  class Request
    class Individual < Request
      def scope(from:) = from.where(from.primary_key => id)

      private

      def id = params[:id]
    end
  end
end
