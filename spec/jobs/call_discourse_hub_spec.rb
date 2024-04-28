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
  end
end
