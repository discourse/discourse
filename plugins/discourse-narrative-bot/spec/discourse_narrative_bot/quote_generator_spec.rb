# frozen_string_literal: true

RSpec.describe DiscourseNarrativeBot::QuoteGenerator do
  fab!(:user)

  def bundled_quotes(locale)
    I18n.with_locale(locale) do
      I18n
        .t("discourse_narrative_bot.quote")
        .values
        .select { |v| v.is_a?(Hash) }
        .map { |q| described_class.format_quote(q[:quote], q[:author]) }
    end
  end

  describe ".generate" do
    it "returns a bundled quote without contacting any external service" do
      expect(bundled_quotes("en")).to include(described_class.generate(user))
    end

    it "localizes the quote to the user's effective locale" do
      SiteSetting.allow_user_locale = true
      user.update!(locale: "fr")

      expect(bundled_quotes("fr")).to include(described_class.generate(user))
    end
  end
end
