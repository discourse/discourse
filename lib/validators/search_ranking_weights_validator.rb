# frozen_string_literal: true

class SearchRankingWeightsValidator
  def initialize(opts = {})
    @opts = opts
  end

  WEIGHT_REGEXP = "1\.0|0\.[0-9]+"
  WEIGHTS_REGEXP = /{(?<d_weight>#{WEIGHT_REGEXP}),(?<c_weight>#{WEIGHT_REGEXP}),(?<b_weight>#{WEIGHT_REGEXP}),(?<a_weight>#{WEIGHT_REGEXP})}/

  def valid_value?(value)
    return true if value.blank?
    value.match(WEIGHTS_REGEXP)
  end

  def error_message
    I18n.t("site_settings.errors.invalid_search_ranking_weights")
  end
end
