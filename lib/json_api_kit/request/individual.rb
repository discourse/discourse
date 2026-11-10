# frozen_string_literal: true

module JsonApiKit
  class Request
    class Individual < Request
      def id = params[:id]
    end
  end
end
