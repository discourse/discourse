require 'spec_helper'

describe ColorSchemeRevisor do

  let(:color)        { Fabricate.build(:color_scheme_color, hex: 'FFFFFF', color_scheme: nil) }
  let(:color_scheme) { Fabricate(:color_scheme, enabled: false, created_at: 1.day.ago, updated_at: 1.day.ago, color_scheme_colors: [color]) }
  let(:valid_params) { { name: color_scheme.name, enabled: color_scheme.enabled, colors: nil } }

  describe "revise" do
    it "does nothing if there are no changes" do
      expect {
        described_class.revise(color_scheme, valid_params.merge(colors: nil))
      }.to_not change { color_scheme.reload.updated_at }
    end

    it "can change the name" do
      described_class.revise(color_scheme, valid_params.merge(name: "Changed Name"))
      color_scheme.reload.name.should == "Changed Name"
    end

    it "can enable and disable" do
      described_class.revise(color_scheme, valid_params.merge(enabled: true))
      color_scheme.reload.should be_enabled
      described_class.revise(color_scheme, valid_params.merge(enabled: false))
      color_scheme.reload.should_not be_enabled
    end

    it "can change colors" do
      described_class.revise(color_scheme, valid_params.merge(colors: [
        {name: color.name, hex: 'BEEF99', opacity: 99}
      ]))
      color_scheme.reload
      color_scheme.colors.size.should == 1
      color_scheme.colors.first.hex.should == 'BEEF99'
      color_scheme.colors.first.opacity.should == 99
    end

    it "disables other color scheme before enabling" do
      prev_enabled = Fabricate(:color_scheme, enabled: true)
      described_class.revise(color_scheme, valid_params.merge(enabled: true))
      prev_enabled.reload.enabled.should == false
      color_scheme.reload.enabled.should == true
    end

    describe "versions" do
      it "doesn't create a new version if colors is not given" do
        expect {
          described_class.revise(color_scheme, valid_params.merge(name: "Changed Name"))
        }.to_not change { color_scheme.reload.version }
      end

      it "creates a new version if colors have changed" do
        old_hex, old_opacity = color.hex, color.opacity
        expect {
          described_class.revise(color_scheme, valid_params.merge(colors: [
            {name: color.name, hex: 'BEEF99', opacity: 99}
          ]))
        }.to change { color_scheme.reload.version }.by(1)
        old_version = ColorScheme.where(versioned_id: color_scheme.id, version: color_scheme.version - 1).first
        old_version.should_not be_nil
        old_version.colors.count.should == color_scheme.colors.count
        old_version.colors_by_name[color.name].hex.should == old_hex
        old_version.colors_by_name[color.name].opacity.should == old_opacity
        color_scheme.colors_by_name[color.name].hex.should == 'BEEF99'
        color_scheme.colors_by_name[color.name].opacity.should == 99
      end

      it "doesn't create a new version if colors have not changed" do
        expect {
          described_class.revise(color_scheme, valid_params.merge(colors: [
            {name: color.name, hex: color.hex, opacity: color.opacity}
          ]))
        }.to_not change { color_scheme.reload.version }
      end
    end
  end

  describe "revert" do
    context "when there are no previous versions" do
      it "does nothing" do
        expect {
          described_class.revert(color_scheme).should == color_scheme
        }.to_not change { color_scheme.reload.version }
      end
    end

    context 'when there are previous versions' do
      let(:new_color_params) { {name: color.name, hex: 'BEEF99', opacity: 99} }

      before do
        @prev_hex, @prev_opacity = color.hex, color.opacity
        described_class.revise(color_scheme, valid_params.merge(colors: [ new_color_params ]))
      end

      it "reverts the colors to the previous version" do
        color_scheme.colors_by_name[new_color_params[:name]].hex.should == new_color_params[:hex]
        expect {
          described_class.revert(color_scheme)
        }.to change { color_scheme.reload.version }.by(-1)
        color_scheme.colors.size.should == 1
        color_scheme.colors.first.hex.should == @prev_hex
        color_scheme.colors.first.opacity.should == @prev_opacity
        color_scheme.colors_by_name[new_color_params[:name]].hex.should == @prev_hex
        color_scheme.colors_by_name[new_color_params[:name]].opacity.should == @prev_opacity
      end

      it "destroys the old version's record" do
        expect {
          described_class.revert(color_scheme)
        }.to change { ColorScheme.count }.by(-1)
        color_scheme.reload.previous_version.should be_nil
      end
    end
  end

end
