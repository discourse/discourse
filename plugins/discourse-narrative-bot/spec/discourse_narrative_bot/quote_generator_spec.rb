# frozen_string_literal: true

RSpec.describe DiscourseNarrativeBot::QuoteGenerator do
  fab!(:user)

  let(:bundled_quotes) do
    I18n.with_locale(user.effective_locale) do
      I18n
        .t("discourse_narrative_bot.quote")
        .values
        .select { |quote| quote.is_a?(Hash) }
        .map { |quote| described_class.format_quote(quote[:quote], quote[:author]) }
    end
  end

  describe ".generate" do
    it "returns a bundled quote without contacting any external service" do
      expect(bundled_quotes).to include(described_class.generate(user))
    end

    it "localizes the quote to the user's effective locale" do
      SiteSetting.allow_user_locale = true
      user.update!(locale: "fr")

      expect(bundled_quotes).to include(described_class.generate(user))
    end
  end
end
