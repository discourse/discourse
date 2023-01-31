# frozen_string_literal: true

RSpec.describe SearchRankingWeightsValidator do
  it 'allows a blank value to be set' do
    expect do
      SiteSetting.search_ranking_weights = ''
    end.not_to raise_error
  end

  it 'raises the right error when value is invalid' do
    expect do
      SiteSetting.search_ranking_weights = 'test'
    end.to raise_error(Discourse::InvalidParameters, /#{I18n.t("site_settings.errors.invalid_search_ranking_weights")}/)

    expect do
      SiteSetting.search_ranking_weights = '{1.1,0.1,0.2,0.3}'
    end.to raise_error(Discourse::InvalidParameters, /#{I18n.t("site_settings.errors.invalid_search_ranking_weights")}/)
  end

  it 'sets the site setting when value is valid' do
    expect do
      SiteSetting.search_ranking_weights = '{0.001,0.2,0.003,1.0}'
    end.to_not raise_error
  end
end
