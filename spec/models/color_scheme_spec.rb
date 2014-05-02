require 'spec_helper'

describe ColorScheme do

  describe '#base_colors' do
    it 'parses the colors.scss file and returns a hash' do
      File.stubs(:readlines).with(described_class::BASE_COLORS_FILE).returns([
        '$primary:   #333333 !default;',
        '$secondary: #ffffff !default;  ',
        '$highlight: #ffff4d;',
        '  $danger:#e45735    !default;',
      ])

      colors = described_class.base_colors
      colors.should be_a(Hash)
      colors['primary'].should == '333333'
      colors['secondary'].should == 'ffffff'
      colors['highlight'].should == 'ffff4d'
      colors['danger'].should == 'e45735'
    end
  end

  let(:valid_params) { {name: "Best Colors Evar", enabled: true, colors: valid_colors} }
  let(:valid_colors) { [
    {name: '$primary_background_color', hex: 'FFBB00'},
    {name: '$secondary_background_color', hex: '888888'}
  ]}

  describe "new" do
    it "can take colors" do
      c = described_class.new(valid_params)
      c.colors.should have(valid_colors.size).colors
      c.colors.first.should be_a(ColorSchemeColor)
      expect {
        c.save.should == true
      }.to change { ColorSchemeColor.count }.by(valid_colors.size)
    end
  end

  describe "destroy" do
    it "also destroys old versions" do
      c1 = described_class.create(valid_params.merge(version: 2))
      c2 = described_class.create(valid_params.merge(versioned_id: c1.id, version: 1))
      other = described_class.create(valid_params)
      expect {
        c1.destroy
      }.to change { described_class.count }.by(-2)
    end
  end

  describe "#enabled" do
    it "returns nil when there is no enabled record" do
      described_class.enabled.should be_nil
    end

    it "returns the enabled color scheme" do
      c = described_class.create(valid_params.merge(enabled: true))
      described_class.enabled.id.should == c.id
    end
  end
end
