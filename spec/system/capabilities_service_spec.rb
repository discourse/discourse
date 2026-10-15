# frozen_string_literal: true

describe "capabilities service" do
  describe "viewport helpers" do
    it "updates viewport matches when the window is resized" do
      def matches(name)
        browser_page.evaluate(
          "function(arguments) { return #{"Discourse.lookup('service:capabilities').viewport[#{name.to_json}]"} }",
          arg: [],
        )
      end

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(matches("sm")).to eq(true)
      expect(matches("lg")).to eq(true)

      resize_window(width: 700) do
        expect(matches("sm")).to eq(true)
        expect(matches("lg")).to eq(false)
      end
    end
  end
end
