require 'rails_helper'

describe Emoji do

  it "returns the correct codepoints" do
    expect(Emoji.replacement_code('1f47d').codepoints).to eq([128125])
  end

  it "handles multiple codepoints" do
    expect(Emoji.replacement_code('1f1e9-1f1ea').codepoints).to eq([127465, 127466])
  end

  it "returns nil for weird cases" do
    expect(Emoji.replacement_code('32')).to be_nil
    expect(Emoji.replacement_code('robin')).to be_nil
  end

end
