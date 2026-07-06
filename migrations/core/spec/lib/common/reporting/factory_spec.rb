# frozen_string_literal: true

require "stringio"

RSpec.describe Migrations::Reporting::Factory do
  describe ".build" do
    # A fake tty-capable IO: the renderer only asks it for `tty?` and `winsize`.
    let(:tty) do
      io = StringIO.new
      def io.tty?
        true
      end
      def io.winsize
        [24, 80]
      end
      io
    end

    around do |example|
      original = ENV["TERM"]
      example.run
      ENV["TERM"] = original
    end

    it "builds the Tui reporter for a capable tty" do
      ENV["TERM"] = "xterm-256color"
      reporter = described_class.build(output: tty)
      expect(reporter).to be_a(Migrations::Reporting::Tui)
      reporter.close
    end

    it "passes the output and titles through to the Tui reporter" do
      ENV["TERM"] = "xterm-256color"
      titles = %w[First Second]
      fake = instance_double(Migrations::Reporting::Tui)
      allow(Migrations::Reporting::Tui).to receive(:new).with(output: tty, titles:).and_return(fake)

      expect(described_class.build(output: tty, titles:)).to be(fake)
      expect(Migrations::Reporting::Tui).to have_received(:new).with(output: tty, titles:)
    end

    it "builds the Plain reporter when stdout is not a tty" do
      expect(described_class.build(output: StringIO.new)).to be_a(Migrations::Reporting::Plain)
    end

    it "passes the output through to the Plain reporter" do
      io = StringIO.new
      reporter = described_class.build(output: io)
      reporter.report_start(1, "Importing users")
      expect(io.string).to include("Importing users")
    end

    it "defaults the output to $stdout" do
      ENV["TERM"] = "dumb"
      fake = instance_double(Migrations::Reporting::Plain)
      allow(Migrations::Reporting::Plain).to receive(:new).with(output: $stdout).and_return(fake)

      expect(described_class.build).to be(fake)
      expect(Migrations::Reporting::Plain).to have_received(:new).with(output: $stdout)
    end

    it "treats output that can't answer tty? as plain" do
      expect(described_class.build(output: Object.new)).to be_a(Migrations::Reporting::Plain)
    end

    it "builds the Plain reporter when TERM is dumb, empty, or unset" do
      ENV["TERM"] = "dumb"
      expect(described_class.build(output: tty)).to be_a(Migrations::Reporting::Plain)

      ENV["TERM"] = ""
      expect(described_class.build(output: tty)).to be_a(Migrations::Reporting::Plain)

      ENV.delete("TERM")
      expect(described_class.build(output: tty)).to be_a(Migrations::Reporting::Plain)
    end
  end
end
