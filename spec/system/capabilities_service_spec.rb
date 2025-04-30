# frozen_string_literal: true

describe "capabilities service", type: :system do
  describe "viewport helpers" do
    it "works" do
      def matches(name)
        page.evaluate_script("Discourse.lookup('service:capabilities').viewport[#{name.to_json}]")
      end

      visit "/"
      expect(page).to have_css("#site-logo")

      expect(matches("sm")).to eq(true)
      expect(matches("lg")).to eq(true)

      resize_window(width: 700) do
        try_until_success do
          expect(matches("sm")).to eq(true)
          expect(matches("lg")).to eq(false)
        end
      end
    end
  end
end
