# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::Endpoints::Gemini::GeminiStreamingDecoder do
  before { enable_current_plugin }

  describe "#decode" do
    it "decodes all events when a chunk ends at byte 1 of a CRLF separator" do
      decoder = described_class.new
      events =
        %w[A B C D].each_with_index.map do |text, index|
          {
            candidates: [{ content: { parts: [{ text: text }], role: "model" } }],
            usageMetadata: {
              candidatesTokenCount: [11, 38, 65, 95][index],
            },
          }
        end
      events.last[:candidates].first[:finishReason] = "STOP"
      data_lines = events.map { |event| "data: #{event.to_json}" }
      chunks = [
        data_lines[0] + "\r\n\r\n",
        data_lines[1] + "\r\n\r\n"[0...1],
        "\r\n\r\n"[1..] + data_lines[2] + "\r\n\r\n",
        data_lines[3] + "\r\n\r\n",
      ]

      decoded = chunks.flat_map { |chunk| decoder.decode(chunk) }

      expect(decoded).to eq(events)
    end

    it "decodes all events when a chunk ends at byte 2 of a CRLF separator" do
      decoder = described_class.new
      events =
        %w[A B C D].each_with_index.map do |text, index|
          {
            candidates: [{ content: { parts: [{ text: text }], role: "model" } }],
            usageMetadata: {
              candidatesTokenCount: [11, 38, 65, 95][index],
            },
          }
        end
      events.last[:candidates].first[:finishReason] = "STOP"
      data_lines = events.map { |event| "data: #{event.to_json}" }
      chunks = [
        data_lines[0] + "\r\n\r\n",
        data_lines[1] + "\r\n\r\n"[0...2],
        "\r\n\r\n"[2..] + data_lines[2] + "\r\n\r\n",
        data_lines[3] + "\r\n\r\n",
      ]

      decoded = chunks.flat_map { |chunk| decoder.decode(chunk) }

      expect(decoded).to eq(events)
    end

    it "decodes all events when a chunk ends at byte 3 of a CRLF separator" do
      decoder = described_class.new
      events =
        %w[A B C D].each_with_index.map do |text, index|
          {
            candidates: [{ content: { parts: [{ text: text }], role: "model" } }],
            usageMetadata: {
              candidatesTokenCount: [11, 38, 65, 95][index],
            },
          }
        end
      events.last[:candidates].first[:finishReason] = "STOP"
      data_lines = events.map { |event| "data: #{event.to_json}" }
      chunks = [
        data_lines[0] + "\r\n\r\n",
        data_lines[1] + "\r\n\r\n"[0...3],
        "\r\n\r\n"[3..] + data_lines[2] + "\r\n\r\n",
        data_lines[3] + "\r\n\r\n",
      ]

      decoded = chunks.flat_map { |chunk| decoder.decode(chunk) }

      expect(decoded).to eq(events)
    end

    it "decodes all events when a chunk ends at byte 1 of a LF separator" do
      decoder = described_class.new
      events =
        %w[A B C D].each_with_index.map do |text, index|
          {
            candidates: [{ content: { parts: [{ text: text }], role: "model" } }],
            usageMetadata: {
              candidatesTokenCount: [11, 38, 65, 95][index],
            },
          }
        end
      events.last[:candidates].first[:finishReason] = "STOP"
      data_lines = events.map { |event| "data: #{event.to_json}" }
      chunks = [
        data_lines[0] + "\n\n",
        data_lines[1] + "\n\n"[0...1],
        "\n\n"[1..] + data_lines[2] + "\n\n",
        data_lines[3] + "\n\n",
      ]

      decoded = chunks.flat_map { |chunk| decoder.decode(chunk) }

      expect(decoded).to eq(events)
    end

    it "decodes the same events at every possible chunk boundary" do
      events = [
        { candidates: [{ content: { parts: [{ text: "Hello" }], role: "model" } }] },
        { candidates: [{ content: { parts: [{ text: " world" }], role: "model" } }] },
      ]

      ["\r\n\r\n", "\n\n"].each do |separator|
        stream = events.map { |event| "data: #{event.to_json}#{separator}" }.join

        (0..stream.bytesize).each do |split_position|
          decoder = described_class.new
          chunks = [stream[0...split_position], stream[split_position..]]

          decoded = chunks.flat_map { |chunk| decoder.decode(chunk) }

          expect(decoded).to eq(events),
          "Failed at byte #{split_position} with separator #{separator.inspect}"
        end
      end
    end
  end
end
