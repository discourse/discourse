# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodePacks::TemplateRenderer do
  describe ".render" do
    it "renders parameters, rows, omissions, and response paths" do
      template = {
        "state" => {
          "$param" => "state",
        },
        "criteria" => {
          "$rows" => "options.values",
          "key" => "key",
          "value" => {
            "$row" => "description",
            "omit_if_blank" => true,
          },
        },
        "optional" => {
          "$param" => "blank",
          "omit_if_blank" => true,
        },
      }
      params = {
        "state" => "body",
        "blank" => "",
        "options" => {
          "values" => [
            { "key" => "a", "description" => "Alpha" },
            { "key" => "b", "description" => "" },
          ],
        },
      }

      expect(described_class.render(template, params:)).to eq(
        "state" => "body",
        "criteria" => {
          "a" => "Alpha",
        },
      )
      expect(described_class.render({ "$response" => "answers.missing" }, response: {})).to be_nil
    end

    it "preserves false and null while omitting only explicitly omitted array entries" do
      template = [
        false,
        nil,
        { "$param" => "false_value", "omit_if_blank" => true },
        { "$param" => "nil_value", "omit_if_blank" => true },
        { "$param" => "empty_value", "omit_if_blank" => true },
      ]

      expect(
        described_class.render(
          template,
          params: {
            "false_value" => false,
            "nil_value" => nil,
            "empty_value" => "",
          },
        ),
      ).to eq([false, nil, false])
    end

    it "resolves array response paths and returns null for invalid traversal" do
      response = { "results" => [{ "label" => "first" }, nil, false] }

      expect(described_class.render({ "$response" => "results.0.label" }, response:)).to eq("first")
      expect(described_class.render({ "$response" => "results.1.label" }, response:)).to be_nil
      expect(described_class.render({ "$response" => "results.2.label" }, response:)).to be_nil
      expect(described_class.render({ "$response" => "results.label" }, response:)).to be_nil
      expect(described_class.render({ "$response" => "results.99" }, response:)).to be_nil
      expect(described_class.render({ "$response" => "results.-1" }, response:)).to be_nil
    end

    it "omits blank unkeyed rows without dropping false or null literals" do
      template = { "$rows" => "rows", "value" => { "$row" => "value", "omit_if_blank" => true } }
      params = {
        "rows" => [{ "value" => "" }, { "value" => false }, { "value" => nil }, { "value" => 0 }],
      }

      expect(described_class.render(template, params:)).to eq([false, 0])
    end

    it "rejects duplicate row keys and oversized output" do
      rows = { "rows" => [{ "id" => "same" }, { "id" => "same" }] }
      template = { "$rows" => "rows", "key" => "id", "value" => { "$row" => "id" } }

      expect { described_class.render(template, params: rows) }.to raise_error(
        DiscourseWorkflows::NodeError,
      )
      expect { described_class.render({ "data" => "large" }, max_bytes: 1) }.to raise_error(
        DiscourseWorkflows::NodeError,
      )
    end
  end
end
