# frozen_string_literal: true

# The client's cleanTagName is checked against the same table, so both sides clean alike.
RSpec.describe DiscourseTagging do
  fixture =
    JSON.parse(
      File.read(Rails.root.join("frontend/discourse/tests/fixtures/tag-clean-parity.json")),
    )

  describe ".clean_tag" do
    fixture
      .fetch("cases")
      .each do |row|
        it(row.fetch("name")) do
          settings = fixture.fetch("settings").merge(row.slice(*fixture.fetch("settings").keys))
          SiteSetting.max_tag_length = settings.fetch("max_tag_length")
          SiteSetting.force_lowercase_tags = settings.fetch("force_lowercase_tags")

          expect(DiscourseTagging.clean_tag(row.fetch("input"))).to eq(row.fetch("expected"))
        end
      end
  end
end
