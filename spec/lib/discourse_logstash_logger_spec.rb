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
          "git_version" => described_class::GIT_VERSION,
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

    context "when `progname` is `sidekiq-exception`" do
      it "logs a JSON string with the `exception.class`, `exception.message`, `job.class`, `job.opts` and `job.problem_db` fields" do
        logger = described_class.logger(logdev: output, type: "test")

        logger.add_with_opts(
          Logger::ERROR,
          "Job exception: some job error message",
          "sidekiq-exception",
          exception_class: "Some::StandardError",
          exception_message: "some job error message",
          context: {
            opts: {
              user_id: 1,
            },
            problem_db: "some_db",
            job: "SomeJob",
          },
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed["exception.class"]).to eq("Some::StandardError")
        expect(parsed["exception.message"]).to eq("some job error message")
        expect(parsed["job.class"]).to eq("SomeJob")
        # first option is for ruby 3.3 and the other for 3.4
        expect(parsed["job.opts"]).to eq('{"user_id"=>1}').or eq('{"user_id" => 1}')
        expect(parsed["job.problem_db"]).to eq("some_db")
      end
    end

    context "when `progname` is `web-exception`" do
      it "logs a JSON string with the `exception.class` and `exception.message` fields" do
        logger = described_class.logger(logdev: output, type: "test")

        logger.add(
          Logger::ERROR,
          "Some::StandardError (this is a normal message)\ntest",
          "web-exception",
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed["exception.class"]).to eq("Some::StandardError")
        expect(parsed["exception.message"]).to eq("this is a normal message")
      end

      it "logs a JSON string with the `exception_class` and `exception_message` fields when the exception message contains newlines" do
        logger = described_class.logger(logdev: output, type: "test")

        logger.add(
          Logger::ERROR,
          "Some::StandardError (\n\nsome error message\n\nsomething else\n\n)\ntest",
          "web-exception",
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed["exception.class"]).to eq("Some::StandardError")
        expect(parsed["exception.message"]).to eq("some error message\n\nsomething else")
      end

      it "includes `REQUEST_URI` from `env` keyword argument in the logged JSON string" do
        logger.add(
          Logger::ERROR,
          lograge_logstash_formatter_formatted_message,
          "web-exception",
          env: {
            "REQUEST_URI" => "header",
          },
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed["request.headers.request_uri"]).to eq("header")
      end

      it "includes `REQUEST_METHOD` from `env` keyword argument in the logged JSON string" do
        logger.add(
          Logger::ERROR,
          lograge_logstash_formatter_formatted_message,
          "web-exception",
          env: {
            "REQUEST_METHOD" => "header",
          },
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed["request.headers.request_method"]).to eq("header")
      end

      it "includes `HTTP_HOST` from `env` keyword argument in the logged JSON string" do
        logger.add(
          Logger::ERROR,
          lograge_logstash_formatter_formatted_message,
          "web-exception",
          env: {
            "HTTP_HOST" => "header",
          },
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed["request.headers.http_host"]).to eq("header")
      end

      it "includes `HTTP_USER_AGENT` from `env` keyword argument in the logged JSON string" do
        logger.add(
          Logger::ERROR,
          lograge_logstash_formatter_formatted_message,
          "web-exception",
          env: {
            "HTTP_USER_AGENT" => "header",
          },
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed["request.headers.http_user_agent"]).to eq("header")
      end

      it "includes `HTTP_ACCEPT` from `env` keyword argument in the logged JSON string" do
        logger.add(
          Logger::ERROR,
          lograge_logstash_formatter_formatted_message,
          "web-exception",
          env: {
            "HTTP_ACCEPT" => "header",
          },
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed["request.headers.http_accept"]).to eq("header")
      end

      it "includes `HTTP_REFERER` from `env` keyword argument in the logged JSON string" do
        logger.add(
          Logger::ERROR,
          lograge_logstash_formatter_formatted_message,
          "web-exception",
          env: {
            "HTTP_REFERER" => "header",
          },
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed["request.headers.http_referer"]).to eq("header")
      end

      it "includes `HTTP_X_FORWARDED_FOR` from `env` keyword argument in the logged JSON string" do
        logger.add(
          Logger::ERROR,
          lograge_logstash_formatter_formatted_message,
          "web-exception",
          env: {
            "HTTP_X_FORWARDED_FOR" => "header",
          },
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed["request.headers.http_x_forwarded_for"]).to eq("header")
      end

      it "does not include keys from `env` keyword argument in the logged JSOn string which are not in the allow list" do
        logger.add(
          Logger::ERROR,
          lograge_logstash_formatter_formatted_message,
          "web-exception",
          env: {
            "SOME_RANDOM_HEADER" => "header",
          },
        )

        output.rewind
        parsed = JSON.parse(output.read.chomp)

        expect(parsed).not_to have_key("request.headers.some_random_header")
      end
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

    it "does not log the event if message matches a pattern configured by `Logster.store.ignore`" do
      original_logster_store_ignore = Logster.store.ignore
      Logster.store.ignore = [/^Some::StandardError/]

      logger.add(
        Logger::ERROR,
        "Some::StandardError (this is a normal message)\ntest",
        "web-exception",
      )

      output.rewind
      expect(output.read.chomp).to be_empty
    ensure
      Logster.store.ignore = original_logster_store_ignore
    end
  end
end
