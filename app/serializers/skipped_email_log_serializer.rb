# frozen_string_literal: true

class SkippedEmailLogSerializer < ApplicationSerializer
  root 'skipped_email_log'

  include EmailLogsMixin

  attributes :skipped_reason

  def skipped_reason
    object.reason
  end
end
