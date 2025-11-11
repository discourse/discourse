# frozen_string_literal: true

class ProblemCheck::AccessTokenInvalid < ::ProblemCheck::InlineProblemCheck
  self.priority = "high"

  private

  def translation_key
    "dashboard.patreon.access_token_invalid"
  end
end
