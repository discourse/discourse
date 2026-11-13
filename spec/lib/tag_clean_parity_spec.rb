# frozen_string_literal: true

# The client's cleanTagName is checked against the same table, so both sides clean alike.
RSpec.describe DiscourseTagging do
  fixture =
    JSON.parse(
      File.read(Rails.root.join("frontend/discourse/tests/fixtures/tag-clean-parity.json")),
    )

  describe ".clean_tag" do
    it "cleans every case in the shared fixture" do
      cases = fixture.fetch("cases")
      cleaned =
        cases.to_h do |row|
          settings = fixture.fetch("settings").merge(row.slice(*fixture.fetch("settings").keys))
          SiteSetting.max_tag_length = settings.fetch("max_tag_length")
          SiteSetting.force_lowercase_tags = settings.fetch("force_lowercase_tags")

          [row.fetch("name"), DiscourseTagging.clean_tag(row.fetch("input"))]
        end

      # Keyed by case name, so a failure's diff names the case.
      expect(cleaned).to eq(cases.to_h { |row| [row.fetch("name"), row.fetch("expected")] })
    end
  end
end
