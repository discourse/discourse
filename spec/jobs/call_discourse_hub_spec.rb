# frozen_string_literal: true

RSpec.describe Jobs::CallDiscourseHub do
  describe "#execute" do
    context "when `include_in_discourse_discover setting` enabled" do
      it "calls `discover_enrollment` method in DiscourseHub" do
        SiteSetting.version_checks = false
        SiteSetting.include_in_discourse_discover = true

        DiscourseHub.stubs(:discover_enrollment).returns(true)

        described_class.new.execute({})
      end
    end

    context "when version_checks enabled" do
      before do
        SiteSetting.version_checks = true
        SiteSetting.include_in_discourse_discover = false
      end

      it "stores missing versions from the hub response" do
        DiscourseHub.stubs(:discourse_version_check).returns(
          {
            "latestVersion" => "2026.3.1",
            "criticalUpdates" => false,
            "missingVersionsCount" => 2,
            "versions" => [
              { "version" => "2026.3.1", "notes" => "Latest release", "critical" => true },
              { "version" => "2026.2.5", "notes" => "Security patch", "critical" => false },
            ],
          },
        )

        described_class.new.execute({})

        expect(DiscourseUpdates.latest_version).to eq("2026.3.1")
        expect(DiscourseUpdates.missing_versions_count).to eq(2)

        missing = DiscourseUpdates.missing_versions
        expect(missing.length).to eq(2)
        expect(missing.first).to eq({ "version" => "2026.3.1", "notes" => "Latest release" })
        expect(missing.second).to eq({ "version" => "2026.2.5", "notes" => "Security patch" })
      end
    end
  end
end
