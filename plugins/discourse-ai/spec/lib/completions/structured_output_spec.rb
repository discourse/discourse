# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::StructuredOutput do
  subject(:structured_output) do
    described_class.new(
      {
        message: {
          type: "string",
        },
        bool: {
          type: "boolean",
        },
        number: {
          type: "integer",
        },
        status: {
          type: "string",
        },
        list: {
          type: "array",
          items: {
            type: "string",
          },
        },
      },
    )
  end

  before { enable_current_plugin }

  describe "Parsing structured output on the fly" do
    it "acts as a buffer for an streamed JSON" do
      chunks = [
        +"{\"message\": \"Line 1\\n",
        +"Line 2\\n",
        +"Line 3\", ",
        +"\"bool\": true,",
        +"\"number\": 4",
        +"2,",
        +"\"status\": \"o",
        +"\\\"k\\\"\"}",
      ]

      structured_output << chunks[0]
      expect(structured_output.read_buffered_property(:message)).to eq("Line 1\n")

      structured_output << chunks[1]
      expect(structured_output.read_buffered_property(:message)).to eq("Line 2\n")

      structured_output << chunks[2]
      expect(structured_output.read_buffered_property(:message)).to eq("Line 3")

      structured_output << chunks[3]
      expect(structured_output.read_buffered_property(:bool)).to eq(true)

      # Waiting for number to be fully buffered.
      structured_output << chunks[4]
      expect(structured_output.read_buffered_property(:bool)).to eq(true)
      expect(structured_output.read_buffered_property(:number)).to be_nil

      structured_output << chunks[5]
      expect(structured_output.read_buffered_property(:number)).to eq(42)

      structured_output << chunks[6]
      expect(structured_output.read_buffered_property(:number)).to eq(42)
      expect(structured_output.read_buffered_property(:bool)).to eq(true)
      expect(structured_output.read_buffered_property(:status)).to eq("o")

      structured_output << chunks[7]
      expect(structured_output.read_buffered_property(:status)).to eq("\"k\"")

      # No partial string left to read.
      expect(structured_output.read_buffered_property(:status)).to eq("")
    end

    it "supports array types" do
      chunks = [
        +"{ \"",
        +"list",
        +"\":",
        +" [\"",
        +"Hello!",
        +" I am",
        +" a ",
        +"chunk\",",
        +"\"There\"",
        +"]}",
      ]

      structured_output << chunks[0]
      structured_output << chunks[1]
      structured_output << chunks[2]
      expect(structured_output.read_buffered_property(:list)).to eq(nil)

      structured_output << chunks[3]
      expect(structured_output.read_buffered_property(:list)).to eq([""])

      structured_output << chunks[4]
      expect(structured_output.read_buffered_property(:list)).to eq(["Hello!"])

      structured_output << chunks[5]
      structured_output << chunks[6]
      structured_output << chunks[7]

      expect(structured_output.read_buffered_property(:list)).to eq(["Hello! I am a chunk"])

      structured_output << chunks[8]
      expect(structured_output.read_buffered_property(:list)).to eq(
        ["Hello! I am a chunk", "There"],
      )

      structured_output << chunks[9]
      expect(structured_output.read_buffered_property(:list)).to eq(
        ["Hello! I am a chunk", "There"],
      )
    end

    it "handles empty newline chunks" do
      chunks = [+"{\"", +"message", +"\":\"", +"Hello!", +"\n", +"\"", +"}"]

      chunks.each { |c| structured_output << c }

      expect(structured_output.read_buffered_property(:message)).to eq("Hello!\n")
    end
  end

  describe "dealing with non-JSON responses" do
    it "treat it as plain text once we determined it's invalid JSON" do
      chunks = [+"I'm not", +"a", +"JSON :)"]

      structured_output << chunks[0]
      expect(structured_output.read_buffered_property(:bob)).to eq(nil)

      structured_output << chunks[1]
      expect(structured_output.read_buffered_property(:bob)).to eq(nil)

      structured_output << chunks[2]

      structured_output.finish
      expect(structured_output.read_buffered_property(:bob)).to eq(nil)
    end

    it "can handle broken JSON" do
      broken_json = <<~JSON
        ```json
        {
          "message": "This is a broken JSON",
          bool: true
        }
      JSON

      structured_output << broken_json
      structured_output.finish

      expect(structured_output.read_buffered_property(:message)).to eq("This is a broken JSON")
      expect(structured_output.read_buffered_property(:bool)).to eq(true)
    end
  end
end
