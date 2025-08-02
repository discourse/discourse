# frozen_string_literal: true

RSpec.describe SearchRankingWeightsValidator do
  it "allows a blank value to be set" do
    expect { SiteSetting.search_ranking_weights = "" }.not_to raise_error
  end

  it "raises the right error when value is invalid" do
    expect { SiteSetting.search_ranking_weights = "test" }.to raise_error(
      Discourse::InvalidParameters,
      /#{I18n.t("site_settings.errors.invalid_search_ranking_weights")}/,
    )

    expect { SiteSetting.search_ranking_weights = "{1.1,0.1,0.2,0.3}" }.to raise_error(
      Discourse::InvalidParameters,
      /#{I18n.t("site_settings.errors.invalid_search_ranking_weights")}/,
    )
  end

  it "sets the site setting when value is valid" do
    expect { SiteSetting.search_ranking_weights = "{0.001,0.2,0.003,1.0}" }.to_not raise_error
  end
end
