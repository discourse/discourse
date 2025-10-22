# frozen_string_literal: true

RSpec.describe ColorSchemeRevisor do
  let(:color) { Fabricate.build(:color_scheme_color, hex: "FFFFFF", color_scheme: nil) }
  let(:color_scheme) do
    Fabricate(
      :color_scheme,
      created_at: 1.day.ago,
      updated_at: 1.day.ago,
      color_scheme_colors: [color],
    )
  end
  let(:dark_color_scheme) { ColorScheme.find_by(name: "Dark") }
  let(:valid_params) { { name: color_scheme.name, colors: nil } }

  describe "revise" do
    it "does nothing if there are no changes" do
      expect {
        ColorSchemeRevisor.revise(color_scheme, valid_params.merge(colors: nil))
      }.to_not change { color_scheme.reload.updated_at }
    end

    it "can change the name" do
      ColorSchemeRevisor.revise(color_scheme, valid_params.merge(name: "Changed Name"))
      expect(color_scheme.reload.name).to eq("Changed Name")
    end

    it "can update the base_scheme_id" do
      ColorSchemeRevisor.revise(
        color_scheme,
        valid_params.merge(base_scheme_id: ColorScheme::NAMES_TO_ID_MAP["Dark"]),
      )
      expect(color_scheme.reload.base_scheme_id).to eq(ColorScheme::NAMES_TO_ID_MAP["Dark"])
    end

    it "can change colors" do
      ColorSchemeRevisor.revise(
        color_scheme,
        valid_params.merge(
          colors: [{ name: color.name, hex: "BEEF99" }, { name: "bob", hex: "AAAAAA" }],
        ),
      )
      color_scheme.reload

      expect(color_scheme.version).to eq(2)
      expect(color_scheme.colors.size).to eq(2)
      expect(color_scheme.colors.find_by(name: color.name).hex).to eq("BEEF99")
      expect(color_scheme.colors.find_by(name: "bob").hex).to eq("AAAAAA")
    end

    it "doesn't make changes when a color is invalid" do
      expect {
        cs =
          ColorSchemeRevisor.revise(
            color_scheme,
            valid_params.merge(colors: [{ name: color.name, hex: "OOPS" }]),
          )
        expect(cs).not_to be_valid
        expect(cs.errors).to be_present
      }.to_not change { color_scheme.reload.version }
      expect(color_scheme.colors.first.hex).to eq(color.hex)
    end

    it "can change the user_selectable column" do
      expect(color_scheme.user_selectable).to eq(false)

      ColorSchemeRevisor.revise(color_scheme, { user_selectable: true })
      expect(color_scheme.reload.user_selectable).to eq(true)
    end
  end
end
