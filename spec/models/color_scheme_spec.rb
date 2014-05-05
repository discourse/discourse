require 'spec_helper'

describe ColorScheme do

  let(:valid_params) { {name: "Best Colors Evar", enabled: true, colors: valid_colors} }
  let(:valid_colors) { [
    {name: '$primary_background_color', hex: 'FFBB00', opacity: '100'},
    {name: '$secondary_background_color', hex: '888888', opacity: '70'}
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
    it "returns the base color scheme when there is no enabled record" do
      described_class.enabled.id.should == 1
    end

    it "returns the enabled color scheme" do
      c = described_class.create(valid_params.merge(enabled: true))
      described_class.enabled.id.should == c.id
    end
  end
end
