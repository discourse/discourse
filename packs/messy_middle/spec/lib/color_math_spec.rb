# frozen_string_literal: true

describe ColorMath do
  describe "#brightness" do
    it "works" do
      expect(ColorMath.brightness("000")).to eq(0)
      expect(ColorMath.brightness("fff")).to eq(255)
    end
  end

  describe "#scale_color_lightness" do
    it "works" do
      expect(ColorMath.scale_color_lightness("000", 0.5)).to eq("808080")
      expect(ColorMath.scale_color_lightness("fff", -0.5)).to eq("808080")
    end

    it "works with non-greyscale colors" do
      expect(ColorMath.scale_color_lightness("f00", 0.5)).to eq("ff8080")
    end
  end

  describe "#dark_light_diff" do
    it "darkens by requested amount if target color is darker than comparison" do
      expect(ColorMath.dark_light_diff("fff", "eee", 0, -0.5)).to eq("808080")
    end

    it "lightens by requested amount if target color is lighter than comparison" do
      expect(ColorMath.dark_light_diff("000", "eee", 0.5, 0)).to eq("808080")
    end
  end
end
