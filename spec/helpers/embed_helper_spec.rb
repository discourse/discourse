# frozen_string_literal: true

RSpec.describe EmbedHelper do
  describe "#embed_post_date_title" do
    it "returns localized long format" do
      date = Time.zone.local(2026, 5, 15, 14, 30)
      expected_format = I18n.t("datetime_formats.formats.long")
      expect(helper.embed_post_date_title(date)).to eq(date.strftime(expected_format))
    end
  end

  describe "#embed_post_date" do
    it "returns relative time for dates within the last day" do
      freeze_time
      expect(helper.embed_post_date(12.hours.ago)).to eq(
        distance_of_time_in_words(12.hours.ago, Time.now),
      )
    end

    it "returns localized format for dates in the current year" do
      freeze_time DateTime.parse("2026-06-15")
      date = 2.months.ago
      expected_format = I18n.t("datetime_formats.formats.short_no_year")
      expect(helper.embed_post_date(date)).to eq(date.strftime(expected_format))
    end

    it "returns localized format for dates in a previous year" do
      date = 2.years.ago
      expected_format = I18n.t("datetime_formats.formats.no_day")
      expect(helper.embed_post_date(date)).to eq(date.strftime(expected_format))
    end
  end
end
