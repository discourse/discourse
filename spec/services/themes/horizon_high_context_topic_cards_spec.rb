# frozen_string_literal: true

RSpec.describe Themes::Action::HorizonHighContextTopicCardsToggled do
  fab!(:horizon_theme) { Theme.horizon_theme }

  before do
    horizon_theme.set_field(
      target: :settings,
      name: "yaml",
      value: File.read(Rails.root.join("themes/horizon/settings.yml")),
    )
    horizon_theme.save!
    horizon_theme.update_columns(enabled: true, user_selectable: true)
    horizon_theme.theme_settings.where(name: "topic_card_high_context").delete_all
    horizon_theme.reload
  end

  describe ".should_display_upcoming_change?" do
    before do
      ThemeSetting.create!(
        theme: horizon_theme,
        name: "topic_card_high_context",
        data_type: ThemeSetting.types[:bool],
        value: "false",
      )
    end

    it "returns true when Horizon is enabled and user-selectable" do
      expect(described_class.should_display_upcoming_change?).to eq(true)
      expect(
        UpcomingChanges::ConditionalDisplay.should_display?(
          :enable_horizon_high_context_topic_cards,
        ),
      ).to eq(true)
    end

    it "returns false when Horizon is disabled" do
      horizon_theme.update_columns(enabled: false)

      expect(described_class.should_display_upcoming_change?).to eq(false)
    end

    it "returns false when Horizon is not user-selectable and is not the default theme" do
      horizon_theme.update_columns(user_selectable: false)
      SiteSetting.default_theme_id = Theme.find(Theme::CORE_THEMES["foundation"]).id

      expect(described_class.should_display_upcoming_change?).to eq(false)
    end

    it "returns true when Horizon is the default theme" do
      horizon_theme.update_columns(user_selectable: false)
      SiteSetting.default_theme_id = horizon_theme.id

      expect(described_class.should_display_upcoming_change?).to eq(true)
    end

    it "returns true when Horizon is user-selectable but not the default theme" do
      horizon_theme.update_columns(user_selectable: true)
      SiteSetting.default_theme_id = Theme.find(Theme::CORE_THEMES["foundation"]).id

      expect(described_class.should_display_upcoming_change?).to eq(true)
    end

    it "returns false when Horizon has no high-context override" do
      horizon_theme.theme_settings.where(name: "topic_card_high_context").delete_all

      expect(described_class.should_display_upcoming_change?).to eq(false)
    end
  end

  describe ".call" do
    it "enables high-context topic cards" do
      horizon_theme.update_setting(:topic_card_high_context, false)
      horizon_theme.save!

      described_class.call(enabled: true)

      expect(horizon_theme.reload.get_setting(:topic_card_high_context)).to eq(true)
    end

    it "disables high-context topic cards" do
      described_class.call(enabled: false)

      expect(horizon_theme.reload.get_setting(:topic_card_high_context)).to eq(false)
    end
  end

  describe "upcoming change event handlers" do
    it "updates Horizon high-context topic cards when the upcoming change toggles" do
      DiscourseEvent.trigger(:upcoming_change_enabled, :enable_horizon_high_context_topic_cards)
      expect(horizon_theme.reload.get_setting(:topic_card_high_context)).to eq(true)

      DiscourseEvent.trigger(:upcoming_change_disabled, :enable_horizon_high_context_topic_cards)
      expect(horizon_theme.reload.get_setting(:topic_card_high_context)).to eq(false)
    end
  end
end
