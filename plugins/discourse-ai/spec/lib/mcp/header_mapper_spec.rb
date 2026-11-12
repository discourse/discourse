# frozen_string_literal: true

RSpec.describe DiscourseAi::Mcp::HeaderMapper do
  def tool_headers(schema, arguments = {})
    described_class.request_headers(
      "tools/call",
      { name: "search", arguments: arguments },
      input_schema: schema,
    )
  end

  describe ".request_headers" do
    it "maps reachable local references and ignores unused definitions" do
      schema = {
        "$defs" => {
          "Region" => {
            "type" => "string",
            "x-mcp-header" => "Region",
          },
          "Place/Config" => {
            "properties" => {
              "active" => {
                "type" => "boolean",
                "x-mcp-header" => "Active",
              },
            },
          },
          "Unused" => {
            "type" => "string",
            "x-mcp-header" => "bad\r\nheader",
          },
        },
        "properties" => {
          "region" => {
            "$ref" => "#/$defs/Region",
          },
          "config" => {
            "$ref" => "#/$defs/Place~1Config",
          },
        },
      }

      expect(tool_headers(schema, region: "West", config: { active: false })).to eq(
        "Mcp-Method" => "tools/call",
        "Mcp-Name" => "search",
        "Mcp-Param-Region" => "West",
        "Mcp-Param-Active" => "false",
      )
    end

    it "resolves array indices, percent-encoded names and empty pointer keys" do
      schema = {
        "$defs" => {
          "Region" => {
            "allOf" => [{ "type" => "string", "x-mcp-header" => "Region" }],
          },
          "Place Config+East" => {
            "type" => "string",
            "x-mcp-header" => "Place",
          },
          "Empty" => {
            "properties" => {
              "" => {
                "type" => "boolean",
                "x-mcp-header" => "Empty",
              },
            },
          },
        },
        "properties" => {
          "region" => {
            "$ref" => "#/$defs/Region/allOf/0",
          },
          "place" => {
            "$ref" => "#/$defs/Place%20Config+East",
          },
          "empty" => {
            "$ref" => "#/$defs/Empty/properties/",
          },
        },
      }

      expect(tool_headers(schema, region: "West", place: "Central", empty: false)).to eq(
        "Mcp-Method" => "tools/call",
        "Mcp-Name" => "search",
        "Mcp-Param-Region" => "West",
        "Mcp-Param-Place" => "Central",
        "Mcp-Param-Empty" => "false",
      )
    end

    it "rejects malformed pointer escapes, array indices and external references" do
      schema = {
        "$defs" => {
          "Region" => {
            "allOf" => [{ "type" => "string" }],
          },
        },
        "properties" => {
          "region" => {
            "$ref" => nil,
          },
        },
      }
      bad_refs = %w[
        #/$defs/Region/allOf/01
        #/$defs/Region/allOf/-
        #/$defs/Region/allOf/1
        #/$defs/Region/allOf/name
        #/$defs/Region~2allOf/0
        #/$defs/Region%GG
        #/$defs/Region%FF
        #Region
        https://schemas.example.com/region
      ]

      bad_refs.each do |ref|
        schema["properties"]["region"]["$ref"] = ref
        expect { tool_headers(schema) }.to raise_error(
          DiscourseAi::Mcp::Client::Error,
          "Unsupported MCP tool schema reference",
        )
      end
    end

    it "rejects annotated cycles but permits unannotated recursive references" do
      node = { "properties" => { "parent" => { "$ref" => "#/$defs/Node" } } }
      schema = { "$defs" => { "Node" => node }, "properties" => { "parent" => node } }
      expect(tool_headers(schema)).to eq("Mcp-Method" => "tools/call", "Mcp-Name" => "search")

      node["properties"]["name"] = { "type" => "string", "x-mcp-header" => "Name" }
      expect { tool_headers(schema) }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
        "Unsupported MCP tool schema reference",
      )
    end

    it "permits unannotated root references and literal annotation data" do
      schema = {
        "properties" => {
          "parent" => {
            "$ref" => "#",
          },
          "entries" => {
            "items" => {
              "properties" => {
                "x-mcp-header" => {
                  "type" => "string",
                },
              },
            },
          },
        },
        "default" => {
          "x-mcp-header" => "literal",
        },
        "examples" => [{ "x-mcp-header" => "literal" }],
        "const" => {
          "x-mcp-header" => "literal",
        },
        "enum" => [{ "x-mcp-header" => "literal" }],
      }
      expect(tool_headers(schema)).to eq("Mcp-Method" => "tools/call", "Mcp-Name" => "search")

      schema["properties"]["region"] = { "type" => "string", "x-mcp-header" => "Region" }
      expect { tool_headers(schema) }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
        "Unsupported MCP tool schema reference",
      )
    end

    it "rejects annotations through unsupported branches inline and through local references" do
      annotation = { "type" => "string", "x-mcp-header" => "Token" }
      branches = {
        "items" => annotation,
        "anyOf" => [{ "$ref" => "#/$defs/Token/allOf/0" }],
        "additionalProperties" => annotation,
        "patternProperties" => {
          "^token$" => annotation,
        },
        "dependentSchemas" => {
          "token" => {
            "properties" => {
              "value" => annotation,
            },
          },
        },
      }

      branches.each do |keyword, value|
        inline = {
          "properties" => {
            "token" => {
              keyword => value,
            },
          },
          "$defs" => {
            "Token" => {
              "allOf" => [annotation],
            },
          },
        }
        referenced = {
          "$defs" => {
            "Nested" => {
              keyword => value,
            },
            "Token" => {
              "allOf" => [annotation],
            },
          },
          "properties" => {
            "token" => {
              "$ref" => "#/$defs/Nested",
            },
          },
        }
        [inline, referenced].each do |schema|
          expect { tool_headers(schema) }.to raise_error(
            DiscourseAi::Mcp::Client::Error,
            "Invalid x-mcp-header annotation",
          )
        end
      end
    end

    it "treats schema-map keys named x-mcp-header as property names" do
      nested = {
        "patternProperties" => {
          "x-mcp-header" => {
            "type" => "string",
          },
        },
        "dependentSchemas" => {
          "x-mcp-header" => {
            "properties" => {
              "other" => {
                "type" => "string",
              },
            },
          },
        },
      }
      schema = {
        "$defs" => {
          "Nested" => nested,
        },
        "properties" => {
          "inline" => {
            "items" => nested,
          },
          "referenced" => {
            "anyOf" => [{ "$ref" => "#/$defs/Nested" }],
          },
        },
      }
      expect(tool_headers(schema)).to eq("Mcp-Method" => "tools/call", "Mcp-Name" => "search")
    end

    it "treats dependentRequired as data even behind unsupported branches and references" do
      required = { "dependentRequired" => { "x-mcp-header" => ["token"] } }
      schema = {
        "dependentRequired" => {
          "x-mcp-header" => ["other"],
        },
        "$defs" => {
          "Required" => required,
        },
        "properties" => {
          "inline" => {
            "anyOf" => [required],
          },
          "referenced" => {
            "items" => {
              "$ref" => "#/$defs/Required",
            },
          },
        },
      }

      expect(tool_headers(schema)).to eq("Mcp-Method" => "tools/call", "Mcp-Name" => "search")
    end

    it "ignores unused and unresolved references but rejects reachable external references" do
      schema = {
        "$defs" => {
          "Unused" => {
            "$ref" => "https://schemas.example.com/tool.json",
          },
        },
        "properties" => {
          "local" => {
            "$ref" => "#/$defs/Missing",
          },
        },
      }
      expect(tool_headers(schema)).to eq("Mcp-Method" => "tools/call", "Mcp-Name" => "search")

      schema["properties"]["remote"] = { "$ref" => "https://schemas.example.com/tool.json" }
      expect { tool_headers(schema) }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
        "Unsupported MCP tool schema reference",
      )
    end

    it "rejects unsafe annotation names, locations, types and duplicate header names" do
      schema = { "properties" => { "token" => { "type" => "string", "x-mcp-header" => "Token" } } }
      ["bad\r\nheader", ""].each do |name|
        schema["properties"]["token"]["x-mcp-header"] = name
        expect { tool_headers(schema) }.to raise_error(DiscourseAi::Mcp::Client::Error)
      end
      schema["properties"]["token"]["x-mcp-header"] = "Token"
      schema["properties"]["token"]["type"] = "number"
      expect { tool_headers(schema) }.to raise_error(DiscourseAi::Mcp::Client::Error)

      schema["properties"]["token"]["type"] = "string"
      schema["properties"]["other"] = { "type" => "string", "x-mcp-header" => "token" }
      expect { tool_headers(schema) }.to raise_error(DiscourseAi::Mcp::Client::Error)
      expect { tool_headers("x-mcp-header" => "Token", "type" => "string") }.to raise_error(
        DiscourseAi::Mcp::Client::Error,
      )
    end

    it "rejects invalid annotated arguments and encodes unsafe header values" do
      schema = {
        "properties" => {
          "count" => {
            "type" => "integer",
            "x-mcp-header" => "Count",
          },
          "region" => {
            "type" => "string",
            "x-mcp-header" => "Region",
          },
        },
      }
      expect(tool_headers(schema, count: 1, region: "Hello, 世界")).to eq(
        "Mcp-Method" => "tools/call",
        "Mcp-Name" => "search",
        "Mcp-Param-Count" => "1",
        "Mcp-Param-Region" => "=?base64?SGVsbG8sIOS4lueVjA==?=",
      )
      expect { tool_headers(schema, count: 2**53) }.to raise_error(
        described_class::InvalidArgumentError,
        "Invalid MCP annotated tool argument",
      )
      expect { tool_headers(schema, count: "1") }.to raise_error(
        described_class::InvalidArgumentError,
      )
    end
  end
end
