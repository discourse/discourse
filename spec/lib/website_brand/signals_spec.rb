# frozen_string_literal: true

RSpec.describe WebsiteBrand::Signals do
  subject(:signals) { described_class.new }

  it "adds up colors that look alike" do
    signals.add("0066cc", weight: 3, source: :variable)
    signals.add("1a75d1", weight: 2, source: :button)
    signals.add("e8590c", weight: 4, source: :link)

    expect(signals.brand).to eq("0066cc")
    expect(signals.candidates).to eq(%w[0066cc e8590c])
  end

  it "limits how much colors seen in passing can count" do
    10.times { signals.add("0066cc", weight: 0.5, source: :background) }
    signals.add("e8590c", weight: 3, source: :theme_color)

    expect(signals.brand).to eq("e8590c")
  end

  it "only takes colors that can carry a brand" do
    signals.add("777777", weight: 10, source: :theme_color)
    signals.add("fdfdfd", weight: 10, source: :theme_color)

    expect(signals.brand).to be_nil
    expect(signals.candidates).to eq([])
    expect(signals.confidence).to eq(:low)
  end

  it "picks an accent with a clearly different hue" do
    signals.add("0066cc", weight: 8, source: :theme_color)
    signals.add("4f46e5", weight: 3, source: :button)
    signals.add("e8590c", weight: 2, source: :button)

    expect(signals.accent).to eq("e8590c")
  end

  it "is more confident the more strongly the page points at its brand color" do
    signals.add("e8590c", weight: 2, source: :button)
    expect(signals.confidence).to eq(:low)

    signals.add("e8590c", weight: 2, source: :button)
    expect(signals.confidence).to eq(:medium)

    signals.add("e8590c", weight: 4, source: :theme_color)
    expect(signals.confidence).to eq(:high)
  end
end
