# frozen_string_literal: true

class SkippedEmailLogSerializer < ApplicationSerializer
  include EmailLogsMixin

  attributes :skipped_reason

  def skipped_reason
    object.reason
  end
end
