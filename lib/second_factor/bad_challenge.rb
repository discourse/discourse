# frozen_string_literal: true

class SecondFactor::BadChallenge < StandardError
  attr_reader :error_translation_key, :status_code

  def initialize(error_translation_key, status_code:)
    @error_translation_key = error_translation_key
    @status_code = status_code
  end
end
