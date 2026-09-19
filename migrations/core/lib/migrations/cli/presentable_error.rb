# frozen_string_literal: true

module Migrations
  module CLI
    # Errors including this module are shown to the user as a clean, red message
    # (no backtrace) by the ExceptionHandler.
    module PresentableError
    end
  end
end
