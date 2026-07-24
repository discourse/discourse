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

    it "builds the Plain reporter when stdout is not a tty" do
      expect(described_class.build(output: StringIO.new)).to be_a(Migrations::Reporting::Plain)
    end

    it "builds the Plain reporter when TERM is dumb or empty" do
      ENV["TERM"] = "dumb"
      expect(described_class.build(output: tty)).to be_a(Migrations::Reporting::Plain)

      ENV["TERM"] = ""
      expect(described_class.build(output: tty)).to be_a(Migrations::Reporting::Plain)
    end
  end
end
