# frozen_string_literal: true

require_relative "../support/system/ember_deprecations"

RSpec.describe EmberDeprecations do
  describe ".record_details" do
    it "records valid unexpected deprecation details" do
      metadata = { expected_js_deprecations: ["expected.deprecation"] }
      logs = [
        {
          message:
            'deprecation_detail:{"id":"reported.deprecation","stack":"stack","reportAtCallSite":true}',
        },
        { message: 'deprecation_detail:{"id":"expected.deprecation","stack":"stack"}' },
        { message: "deprecation_detail:not-json" },
      ]

      described_class.record_details(logs, metadata)

      expect(metadata[:js_deprecation_details]).to eq(
        [{ "id" => "reported.deprecation", "stack" => "stack", "reportAtCallSite" => true }],
      )
    end
  end
end
