# frozen_string_literal: true

describe "capabilities service" do
  describe "viewport helpers" do
    it "works" do
      def matches(name)
        page.evaluate_script("Discourse.lookup('service:capabilities').viewport[#{name.to_json}]")
      end

      visit "/"

      expect(matches("sm")).to eq(true)
      expect(matches("lg")).to eq(true)

      resize_window(width: 700) do
        expect(matches("sm")).to eq(true)
        expect(matches("lg")).to eq(false)
      end
    end
  end
end
