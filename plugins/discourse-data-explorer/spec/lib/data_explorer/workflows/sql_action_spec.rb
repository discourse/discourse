# frozen_string_literal: true

RSpec.describe DiscourseDataExplorer::Workflows::SqlAction do
  fab!(:user)

  describe "#execute" do
    it "substitutes named params into the query" do
      result =
        execute_node(
          configuration: {
            "query" => "SELECT username FROM users WHERE id = :user_id",
            "params" => [{ "name" => "user_id", "value" => user.id.to_s }],
          },
        )

      expect(result["username"]).to eq(user.username)
    end

    it "raises when no query is provided" do
      expect { execute_node(configuration: { "query" => "" }) }.to raise_error(
        ArgumentError,
        "No SQL query provided",
      )
    end
  end

  describe ".property_schema" do
    it "includes output_fields" do
      schema = described_class.property_schema
      expect(schema).to have_key(:output_fields)
      expect(schema[:output_fields][:type]).to eq(:array)
      expect(schema[:output_fields][:ui][:hidden]).to eq(true)
    end
  end
end
