# frozen_string_literal: true

module Themes
  # Computes a version token for a baked block-layout field value. It lets a
  # publish detect that another admin published the same outlet since the
  # layout was last loaded (a stale publish). The token is derived from `value_baked`
  # (the canonical baked JSON), so it changes if and only if the live layout
  # content changes — `updated_at` is unsafe for sub-second bakes. Returns ""
  # for a blank value (no live field yet).
  module BlockLayoutVersion
    def self.token_for(value_baked)
      return "" if value_baked.blank?
      Digest::SHA256.hexdigest(value_baked)
    end
  end
end
