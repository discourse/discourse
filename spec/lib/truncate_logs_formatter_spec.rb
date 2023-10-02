# frozen_string_literal: true

RSpec.describe TruncateLogsFormatter do
  describe "#call" do
    describe "when the formatter is initialized with `log_line_max_chars` of 10" do
      let(:formatter) { TruncateLogsFormatter.new(log_line_max_chars: 10) }

      describe "when the messages is 5 characters long" do
        it "should not carry out any truncation of the message" do
          expect(formatter.call(nil, nil, nil, "abcde")).to eq("abcde")
        end
      end

      describe "when the message is 10 characters long" do
        it "should not carry out any truncation of the message" do
          expect(formatter.call(nil, nil, nil, "aaaaaaaaaa")).to eq("aaaaaaaaaa")
        end
      end

      describe "when the message is 11 characters long" do
        it "should truncate the message with the right postfix" do
          expect(formatter.call(nil, nil, nil, "aaaaaaaaaaa")).to eq("aaaaaaaaaa...(truncated)")
        end

        it "should truncate the message with the right postfix while preserving newlines" do
          expect(formatter.call(nil, nil, nil, "aaaaaaaaaaa\n")).to eq("aaaaaaaaaa...(truncated)\n")
        end
      end
    end
  end
end
