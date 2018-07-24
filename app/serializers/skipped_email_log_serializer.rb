class SkippedEmailLogSerializer < ApplicationSerializer
  include EmailLogsMixin

  attributes :skipped_reason

  def skipped_reason
    object.reason
  end
end
