# frozen_string_literal: true

RSpec.describe Migrations::Conversion::PipeProgressChannel do
  subject(:channel) { described_class.new(io) }

  let(:io) { StringIO.new }

  # The channel owns the line format in both directions, so pin it with
  # round-trips: whatever the writer emits, `.parse` reads back.
  it "round-trips a progress batch" do
    channel.report_progress(progress: 25, warnings: 1, errors: 2)

    expect(described_class.parse(io.string)).to eq([:progress, 25, 1, 2])
  end

  it "round-trips a result as one line, embedded newlines included" do
    channel.report_result("hosts" => { "evil.example\ncom" => 3 })

    line = io.string
    expect(line.lines.count).to eq(1)
    expect(described_class.parse(line)).to eq(
      [:result, { "hosts" => { "evil.example\ncom" => 3 } }],
    )
  end

  it "parses an unknown tag to nil" do
    expect(described_class.parse("x whatever\n")).to be_nil
  end
end
