# frozen_string_literal: true

RSpec.describe DiscourseLogstashLogger do
  let(:lograge_logstash_formatter_formatted_message) do
    "{\"method\":\"GET\",\"path\":\"/\",\"format\":\"html\",\"controller\":\"ListController\",\"action\":\"latest\",\"status\":200,\"allocations\":242307,\"duration\":178.2,\"view\":78.36,\"db\":0.0,\"params\":\"\",\"ip\":\"127.0.0.1\",\"username\":null,\"@timestamp\":\"2024-07-01T07:51:11.283Z\",\"@version\":\"1\",\"message\":\"[200] GET / (ListController#latest)\"}"
  end

  let(:output) { StringIO.new }
  let(:logger) { described_class.logger(logdev: output, type: "test") }

  describe "#add" do
    it "logs a JSON string with the right fields" do
      logger.add(Logger::INFO, lograge_logstash_formatter_formatted_message)
      output.rewind

      expect(output.read.chomp).to eq(
        {
          "message" => "[200] GET / (ListController#latest)",
          "severity" => 1,
          "severity_name" => "INFO",
          "pid" => described_class::PROCESS_PID,
          "type" => "test",
          "host" => described_class::HOST,
          "method" => "GET",
          "path" => "/",
          "format" => "html",
          "controller" => "ListController",
          "action" => "latest",
          "status" => 200,
          "allocations" => 242_307,
          "duration" => 178.2,
          "view" => 78.36,
          "db" => 0.0,
          "params" => "",
          "ip" => "127.0.0.1",
          "username" => nil,
          "@timestamp" => "2024-07-01T07:51:11.283Z",
          "@version" => "1",
        }.to_json,
      )
    end

    it "accepts an error object as the message" do
      logger = described_class.logger(logdev: output, type: "test")
      logger.add(Logger::ERROR, StandardError.new("error message"))
      output.rewind
      parsed = JSON.parse(output.read.chomp)
      expect(parsed["message"]).to eq("error message")
    end

    it "logs a JSON string with the right fields when `customize_event` attribute is set" do
      logger =
        described_class.logger(
          logdev: output,
          type: "test",
          customize_event: ->(event) { event["custom"] = "custom" },
        )

      logger.add(Logger::INFO, lograge_logstash_formatter_formatted_message)
      output.rewind
      parsed = JSON.parse(output.read.chomp)

      expect(parsed["custom"]).to eq("custom")
    end

    it "does not log a JSON string with the `backtrace` field when severity is less than `Logger::WARN`" do
      logger.add(
        Logger::INFO,
        lograge_logstash_formatter_formatted_message,
        nil,
        backtrace: "backtrace",
      )

      output.rewind
      parsed = JSON.parse(output.read.chomp)

      expect(parsed).not_to have_key("backtrace")
    end

    it "logs a JSON string with the `backtrace` field when severity is at least `Logger::WARN`" do
      logger.add(
        Logger::ERROR,
        lograge_logstash_formatter_formatted_message,
        nil,
        backtrace: "backtrace",
      )

      output.rewind
      parsed = JSON.parse(output.read.chomp)

      expect(parsed["backtrace"]).to eq("backtrace")
    end

    described_class::ALLOWED_HEADERS_FROM_ENV.each do |header|
      it "does not include `#{header}` from `env` keyword argument in the logged JSON string when severity is less than `Logger::WARN`" do
        logger.add(
          Logger::INFO,
          lograge_logstash_formatter_formatted_message,
          nil,
          env: {
            header => "header",
          },
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed).not_to have_key("request.headers.#{header.downcase}")
      end

      it "includes `#{header}` from `env` keyword argument in the logged JSON string when severity is at least `Logger::WARN`" do
        logger.add(
          Logger::ERROR,
          lograge_logstash_formatter_formatted_message,
          nil,
          env: {
            header => "header",
          },
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed["request.headers.#{header.downcase}"]).to eq("header")
      end
    end

    it "does not include keys from `env` keyword argument in the logged JSOn string which are not in the allow list" do
      logger.add(
        Logger::ERROR,
        lograge_logstash_formatter_formatted_message,
        nil,
        env: {
          "SOME_RANDOM_HEADER" => "header",
        },
      )

      output.rewind
      parsed = JSON.parse(output.read.chomp)

      expect(parsed).not_to have_key("request.headers.some_random_header")
    end
  end
end
