# frozen_string_literal: true

RSpec.describe Vips do
  describe ".run" do
    before { Rails.stubs(env: ActiveSupport::EnvironmentInquirer.new(environment)) }

    let(:environment) { "development" }

    it "applies bounded wall-clock and CPU time by default" do
      Discourse::SafeExec
        .expects(:capture)
        .with do |*command, **options|
          command == %w[nice -n 10 vips --version] && options[:timeout] == 5 &&
            options[:read].include?("/etc/fonts") &&
            options[:rlimits] ==
              {
                cpu_seconds: 5,
                memory_bytes: 4 * 1024 * 1024 * 1024,
                file_size_bytes: 10 * 1024 * 1024 * 1024,
                open_files: 1024,
              }
        end
        .returns("vips-8.18.4\n")

      expect(described_class.run("--version")).to eq("vips-8.18.4\n")
    end

    it "runs multiple operations in sequence" do
      Discourse::SafeExec
        .expects(:capture)
        .with do |*command, **|
          command ==
            [
              "nice",
              "-n",
              "10",
              "sh",
              "-c",
              "vips text /tmp/glyph.png A\\;\\ touch\\ /tmp/exploit && vips gravity /tmp/glyph.png /tmp/avatar.png centre 360 360",
            ]
        end
        .returns("")

      described_class.run(
        ["text", "/tmp/glyph.png", "A; touch /tmp/exploit"],
        %w[gravity /tmp/glyph.png /tmp/avatar.png centre 360 360],
      )
    end

    context "when running in production" do
      let(:environment) { "production" }

      it "fails when Landlock is unavailable" do
        Discourse::SafeExec.stubs(landlock_supported?: false)

        expect { described_class.run("--version") }.to raise_error(
          Discourse::Utils::CommandError,
          "Cannot run libvips because Landlock sandboxing is unavailable",
        )
      end

      it "runs when Landlock is available" do
        Discourse::SafeExec.stubs(landlock_supported?: true)
        Discourse::SafeExec.stubs(capture: "vips-8.18.0\n")

        expect(described_class.run("--version")).to eq("vips-8.18.0\n")
      end
    end

    context "when running locally" do
      it "retains the SafeExec fallback" do
        Discourse::SafeExec.stubs(landlock_supported?: false)
        Discourse::SafeExec.stubs(capture: "vips-8.18.0\n")

        expect(described_class.run("--version")).to eq("vips-8.18.0\n")
      end
    end
  end
end
