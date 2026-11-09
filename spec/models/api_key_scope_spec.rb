# frozen_string_literal: true

RSpec.describe ApiKeyScope do
  describe ".find_urls" do
    it "returns the URL and method for creating posts" do
      expect(ApiKeyScope.find_urls(actions: ["posts#create"], methods: [])).to contain_exactly(
        "/posts (POST)",
      )
    end

    it "returns Logster URLs" do
      expect(ApiKeyScope.find_urls(actions: [Logster::Web], methods: [])).to contain_exactly(
        "/logs/messages.json (POST)",
        "/logs/show/:id.json (GET)",
      )
    end
  end

  describe ".restrictable_parameters" do
    it "returns ordinary parameters followed by deduplicated path parameters" do
      mapping = { params: %w[status topic_id], path_params: %i[topic_id external_id] }

      expect(described_class.restrictable_parameters(mapping)).to eq(
        %i[status topic_id external_id],
      )
    end

    it "returns nil when a mapping has no restrictable parameters" do
      expect(described_class.restrictable_parameters({ actions: %w[topics#show] })).to be_nil
      expect(described_class.restrictable_parameters(nil)).to be_nil
    end
  end

  describe ".build_from_params" do
    it "builds scopes with their restrictable parameters split into lists" do
      scopes =
        described_class.build_from_params(
          [{ "scope_id" => "topics:write", "topic_id" => "1,2", "unrelated" => "3" }],
        )

      expect(scopes.map(&:attributes)).to contain_exactly(
        include(
          "resource" => "topics",
          "action" => "write",
          "allowed_parameters" => {
            "topic_id" => %w[1 2],
          },
        ),
      )
    end

    it "drops blank parameters" do
      scopes = described_class.build_from_params([{ scope_id: "topics:write", topic_id: "" }])

      expect(scopes.first.allowed_parameters).to be_empty
    end

    it "rejects unknown and missing scopes" do
      [
        { scope_id: "topics:explode" },
        { scope_id: "nope" },
        {},
        "topics:write",
      ].each do |scope_params|
        expect { described_class.build_from_params([scope_params]) }.to raise_error(
          Discourse::InvalidParameters,
        )
      end
    end
  end

  describe ".scope_mappings" do
    it "does not define a granular scope for about requests" do
      expect(described_class.scope_mappings).not_to have_key(:about)
    end
  end
end
