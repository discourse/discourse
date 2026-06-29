# frozen_string_literal: true

module Migrations
  module Conversion
    # Raised at the end of a run when one or more steps failed or were skipped.
    # The converter logs per-item errors and keeps going, so this is the single
    # signal the CLI turns into a non-zero exit; its message is the run summary
    # shown to the user (no backtrace).
    class ConvertError < StandardError
      include CLI::PresentableError
    end
  end
end
