# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NormalizedFilter do
  fab!(:data_table) do
    Fabricate(
      :discourse_workflows_data_table,
      columns: [
        { "name" => "email", "type" => "string" },
        { "name" => "score", "type" => "number" },
      ],
    )
  end

  describe "with a valid filter" do
    subject(:model) do
      described_class.new(
        data_table:,
        filter: {
          "type" => "and",
          "filters" => [{ "columnName" => "email", "condition" => "eq", "value" => "a@b.com" }],
        },
      )
    end

    it "returns normalized value" do
      expect(model.value).to eq(
        "type" => "and",
        "filters" => [{ "columnName" => "email", "condition" => "eq", "value" => "a@b.com" }],
      )
    end
  end

  describe "with an empty filter" do
    subject(:model) { described_class.new(data_table:, filter: {}) }

    it "is invalid" do
      expect(model).not_to be_valid
      expect(model.errors[:base]).to include(match(/must not be empty/))
    end
  end

  describe "with an empty optional filter" do
    subject(:model) { described_class.new(data_table:, filter: {}, optional: true) }

    it "returns nil value" do
      expect(model.value).to be_nil
    end
  end

  describe "with an unknown column name" do
    subject(:model) do
      described_class.new(
        data_table:,
        filter: {
          "type" => "and",
          "filters" => [{ "columnName" => "nonexistent", "condition" => "eq", "value" => "x" }],
        },
      )
    end

    it "is invalid" do
      expect(model).not_to be_valid
      expect(model.errors[:base]).to include(match(/Unknown column name/))
    end
  end

  describe "with an unsupported condition" do
    subject(:model) do
      described_class.new(
        data_table:,
        filter: {
          "type" => "and",
          "filters" => [{ "columnName" => "email", "condition" => "regex", "value" => "x" }],
        },
      )
    end

    it "is invalid" do
      expect(model).not_to be_valid
      expect(model.errors[:base]).to include(match(/Unsupported filter condition/))
    end
  end

  describe "with too many filter conditions" do
    subject(:model) do
      filters =
        (described_class::MAX_FILTER_CONDITIONS + 1).times.map do
          { "columnName" => "email", "condition" => "eq", "value" => "a@b.com" }
        end

      described_class.new(data_table:, filter: { "type" => "and", "filters" => filters })
    end

    it "is invalid" do
      expect(model).not_to be_valid
      expect(model.errors[:base]).to include(
        match(/more than #{described_class::MAX_FILTER_CONDITIONS} conditions/),
      )
    end
  end

  describe "with an ilike condition" do
    subject(:model) do
      described_class.new(
        data_table:,
        filter: {
          "type" => "and",
          "filters" => [{ "columnName" => "email", "condition" => "ilike", "value" => "alice" }],
        },
      )
    end

    it "passes the value through without wrapping" do
      expect(model.value.dig("filters", 0, "value")).to eq("alice")
    end
  end
end
