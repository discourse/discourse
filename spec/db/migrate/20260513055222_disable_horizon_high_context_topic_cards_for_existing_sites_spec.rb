# frozen_string_literal: true

require Rails.root.join(
          "db/migrate/20260513055222_disable_horizon_high_context_topic_cards_for_existing_sites.rb",
        )

RSpec.describe DisableHorizonHighContextTopicCardsForExistingSites do
  fab!(:horizon_theme) { Theme.horizon_theme }

  before do
    @original_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    horizon_theme.theme_settings.where(name: "topic_card_high_context").delete_all
  end

  after { ActiveRecord::Migration.verbose = @original_verbose }

  it "stores the previous default for existing sites without a Horizon override" do
    Migration::Helpers.stubs(:existing_site?).returns(true)

    described_class.new.up

    expect(
      horizon_theme.theme_settings.find_by(name: "topic_card_high_context"),
    ).to have_attributes(data_type: ThemeSetting.types[:bool], value: "false")
  end

  it "preserves an existing Horizon override" do
    Migration::Helpers.stubs(:existing_site?).returns(true)
    ThemeSetting.create!(
      theme: horizon_theme,
      name: "topic_card_high_context",
      data_type: ThemeSetting.types[:bool],
      value: "true",
    )

    expect { described_class.new.up }.not_to change {
      horizon_theme.theme_settings.where(name: "topic_card_high_context").count
    }
    expect(horizon_theme.theme_settings.find_by(name: "topic_card_high_context").value).to eq(
      "true",
    )
  end

  it "does not create an override for new sites" do
    Migration::Helpers.stubs(:existing_site?).returns(false)

    described_class.new.up

    expect(horizon_theme.theme_settings.find_by(name: "topic_card_high_context")).to eq(nil)
  end
end
