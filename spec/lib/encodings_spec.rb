# frozen_string_literal: true

RSpec.describe Encodings do
  it "strips a leading BOM" do
    expect(Encodings.delete_bom!(+"#{Encodings::BOM}hello")).to eq("hello")
  end

  it "replaces invalid bytes" do
    expect(Encodings.force_utf8("caf\xFFe")).to eq("cafe")
  end
end
