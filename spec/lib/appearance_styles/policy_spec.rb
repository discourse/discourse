# frozen_string_literal: true

RSpec.describe AppearanceStyles::Policy do
  def run(draft)
    described_class.call(draft)
  end

  def expect_valid(draft)
    result = run(draft)
    expect(result.errors).to eq([])
    result.css
  end

  def expect_error(draft, message)
    result = run(draft)
    expect(result).not_to be_valid
    expect(result.css).to be_nil
    expect(result.errors.join("\n")).to include(message)
  end

  describe "variables" do
    it "puts root variables on the root element outside the admin area" do
      css = expect_valid(variables: { "--d-border-radius" => "12px" })

      expect(css).to include(":root:not(:has(> body.admin-interface)) {")
      expect(css).to include("--d-border-radius: 12px;")
    end

    it "accepts palette variables and light-dark colors" do
      expect_valid(
        variables: {
          "--d-button-primary-bg-color" => "var(--tertiary)",
          "--d-link-color" => "light-dark(#0a7, #4fd)",
          "--d-sidebar-background" => "color-mix(in srgb, var(--secondary) 90%, var(--tertiary))",
        },
      )
    end

    it "places scoped variables on the selector core defines them on" do
      css = expect_valid(variables: { "--d-logo-height" => "3em" })

      expect(css).to include("body:not(.admin-interface) .d-header .title {")
      expect(css).not_to include(":root")
    end

    it "treats border variables as borders, whatever their default looks like" do
      expect_error(
        { variables: { "--d-input-border--disabled" => "var(--primary-low)" } },
        "border needs a style",
      )
      expect_valid(variables: { "--d-input-border--disabled" => "1px solid var(--primary-low)" })
    end

    it "lets buttons be pill-shaped but keeps other corners bounded" do
      expect_valid(variables: { "--d-button-border-radius" => "9999px" })
      expect_error({ variables: { "--d-border-radius" => "9999px" } }, "outside 0px to 32px")
    end

    it "rejects unknown, excluded and out-of-bounds variables" do
      expect_error({ variables: { "--d-made-up" => "1px" } }, "unknown variable")
      expect_error({ variables: { "--d-skeleton-gap" => "1px" } }, "not authorable")
      expect_error({ variables: { "--d-max-width" => "4000px" } }, "outside 960px to 1600px")
      expect_error({ variables: { "--d-border-radius" => "-4px" } }, "negative values")
    end
  end

  describe "rules" do
    it "renders area rules with states and media" do
      css =
        expect_valid(
          rules: [
            {
              area: "topic_list_item",
              state: "hover",
              media: "desktop",
              declarations: {
                "box-shadow" => "0 2px 8px rgba(var(--primary-rgb), 0.08)",
              },
            },
          ],
        )

      expect(css).to include("@media (min-width: 768px) {")
      expect(css).to include("body:not(.admin-interface) .topic-list-item:hover {")
    end

    it "prefixes every selector in a multi-selector area" do
      css =
        expect_valid(
          rules: [{ area: "post_headings", declarations: { "text-transform" => "uppercase" } }],
        )

      expect(css).to include(
        "body:not(.admin-interface) .cooked h1, body:not(.admin-interface) .cooked h2, body:not(.admin-interface) .cooked h3 {",
      )
    end

    it "styles the page body itself" do
      css =
        expect_valid(
          rules: [{ area: "page", declarations: { "background-color" => "var(--secondary)" } }],
        )

      expect(css).to start_with("body:not(.admin-interface) {")
    end

    it "allows palette gradients and hiding hideable areas" do
      expect_valid(
        rules: [
          {
            area: "header",
            declarations: {
              "background" => "linear-gradient(90deg, var(--primary), var(--primary-high))",
              "color" => "var(--secondary)",
            },
          },
          { area: "share_button", declarations: { "display" => "none" } },
        ],
      )
    end

    it "rejects hiding critical areas, unknown areas and bad states" do
      expect_error(
        { rules: [{ area: "header", declarations: { "display" => "none" } }] },
        "cannot be hidden",
      )
      expect_error(
        { rules: [{ area: ".d-header", declarations: { "color" => "var(--primary)" } }] },
        "unknown area",
      )
      expect_error(
        {
          rules: [
            { area: "header", state: "hover", declarations: { "color" => "var(--primary)" } },
          ],
        },
        "state \"hover\" is not allowed",
      )
    end

    it "rejects layout and positioning properties" do
      %w[
        position
        z-index
        transform
        content
        pointer-events
        filter
        width
        animation
      ].each do |property|
        expect_error(
          { rules: [{ area: "post", declarations: { property => "0" } }] },
          "property is not allowed",
        )
      end
    end
  end

  describe "hostile values" do
    def declare(value, property: "background")
      { rules: [{ area: "post", declarations: { property => value } }] }
    end

    it "rejects urls, escapes, at-rules, importance, comments and braces" do
      expect_error(declare("url(https://evil.example/x.png)"), "\"url(\" is not allowed")
      expect_error(declare("u\\72l(https://evil.example)"), "character \"\\\\\" is not allowed")
      expect_error(declare("@import 'x'"), "is not allowed")
      expect_error(declare("var(--primary) !important"), "character \"!\" is not allowed")
      expect_error(declare("var(--primary) /* x */"), "is not allowed")
      expect_error(declare("red} body{display:none"), "is not allowed")
      expect_error(declare("expression(alert(1))"), "\"expression\" is not allowed")
      expect_error(declare("image-set(x 1x)"), "is not allowed")
    end

    it "requires palette-aware colors" do
      expect_error(declare("#ff0000", property: "color"), "must be inside light-dark")
      expect_error(declare("red", property: "color"), "is not a palette color")
      expect_error(declare("rgb(255, 0, 0)", property: "color"), "must use a palette variable")
      expect_error(
        declare("light-dark(red, #400)", property: "color"),
        "light-dark() takes hex colors",
      )
      expect_valid(declare("rgba(var(--tertiary-rgb), 0.2)", property: "background-color"))
      expect_error(
        declare("rgba(var(--tertiary-rgb), 0.2)", property: "color"),
        "text needs an opaque color",
      )
    end

    it "only lets var() reference palette and design variables, without fallbacks" do
      expect_error(
        declare("var(--evil)", property: "color"),
        "must reference a palette or design variable",
      )
      expect_error(declare("var(--primary, red)", property: "color"), "fallbacks are not allowed")
    end

    it "produces CSS that the theme SCSS compiler accepts" do
      result =
        run(
          variables: {
            "--d-border-radius" => "12px",
            "--d-link-color" => "light-dark(#0a7, #4fd)",
            "--d-logo-height" => "3em",
          },
          rules: [
            {
              area: "header",
              declarations: {
                "background" => "linear-gradient(90deg, var(--primary), var(--primary-high))",
                "color" => "var(--secondary)",
              },
            },
            {
              area: "topic_list_item",
              state: "hover",
              media: "desktop",
              declarations: {
                "box-shadow" => "0 2px 8px rgba(var(--primary-rgb), 0.08)",
              },
            },
          ],
        )
      expect(result.errors).to eq([])

      compiled, _map = Stylesheet::Compiler.compile(result.css, "assistant.scss")

      expect(compiled).to include(":root:not(:has(>body.admin-interface))")
      expect(compiled).to include("light-dark(#0a7, #4fd)").or include("light-dark(#0a7,#4fd)")
      expect(compiled).to include("body:not(.admin-interface) .topic-list-item:hover")
    end

    it "bounds sizes, opacity, shadows and transitions" do
      expect_error(declare("2px 2px 200px var(--primary)", property: "box-shadow"), "outside")
      expect_error(declare("0.1", property: "opacity"), "expected a number from 0.6 to 1")
      expect_error(
        declare("transform 0.2s ease", property: "transition"),
        "transitions are limited",
      )
      expect_error(declare("opacity 2s ease", property: "transition"), "up to 300ms")
      expect_error(declare("200px", property: "font-size"), "outside 11px to 48px")
      expect_error(declare("-10px", property: "margin"), "negative values")
      expect_valid(declare("background-color 150ms ease-in-out", property: "transition"))
    end

    it "bounds the length a value works out to, whatever form it takes" do
      expect_error(declare("0", property: "font-size"), "outside 11px to 48px")
      expect_error(declare("calc(16px * 4)", property: "font-size"), "outside 11px to 48px")
      expect_error(declare("max(12px, 60px)", property: "font-size"), "outside 11px to 48px")
      expect_error(declare("50%", property: "font-size"), "outside 11px to 48px")
      expect_error(declare("var(--font-down-5)", property: "font-size"), "outside 11px to 48px")
      expect_error(declare("var(--d-max-width)", property: "font-size"), "outside 11px to 48px")
      expect_error(declare("10%", property: "padding"), "percentages aren't allowed")
      expect_error(declare("calc(100% - 4px)", property: "padding"), "can't be known")
      expect_error(
        { variables: { "--d-topic-list-title-font-size" => "calc(var(--font-up-6) * 3)" } },
        "outside 11px to 48px",
      )

      expect_valid(declare("calc(var(--font-up-1) * 1.2)", property: "font-size"))
      expect_valid(declare("clamp(14px, 1.1em, 20px)", property: "font-size"))
      expect_valid(declare("var(--space-4) var(--space-2)", property: "padding"))
      expect_valid(declare("0", property: "margin"))
      expect_valid(declare("50%", property: "border-radius"))
    end

    it "checks a new text color against the background core gives the area" do
      expect_error(
        { rules: [{ area: "primary_button", declarations: { "color" => "var(--tertiary)" } }] },
        "rules[0]: text on background is",
      )
      expect_error(
        {
          rules: [
            {
              area: "primary_button",
              state: "hover",
              declarations: {
                "color" => "var(--d-button-primary-bg-color--hover)",
              },
            },
          ],
        },
        "rules[0]: text on background is",
      )
      expect_valid(
        {
          rules: [
            { area: "primary_button", declarations: { "color" => "light-dark(#000000, #000000)" } },
          ],
        },
      )
      expect_valid(declare("var(--primary)", property: "color"))
    end

    it "only accepts colors whose readability can be checked" do
      expect_error(
        declare("light-dark(rgb(255, 0, 0), #400)", property: "color"),
        "light-dark() takes hex colors",
      )
      expect_error(
        {
          rules: [
            { area: "primary_button", declarations: { "color" => "rgb(var(--tertiary-rgb))" } },
          ],
        },
        "rules[0]: text on background is",
      )
      expect_error(
        {
          rules: [
            { area: "primary_button", declarations: { "background-color" => "currentcolor" } },
          ],
        },
        "can't tell how readable",
      )
      expect_valid(declare("rgba(var(--tertiary-rgb), 0.2)", property: "background-color"))
    end

    it "needs text to be opaque" do
      expect_error(
        { rules: [{ area: "primary_button", declarations: { "color" => "transparent" } }] },
        "text needs an opaque color",
      )
      expect_error(
        {
          rules: [
            {
              area: "primary_button",
              declarations: {
                "color" => "rgba(var(--secondary-rgb), 0)",
              },
            },
          ],
        },
        "text needs an opaque color",
      )
      expect_error(
        { variables: { "--d-button-primary-text-color" => "transparent" } },
        "text needs an opaque color",
      )
    end

    it "checks a new background against the text core shows in every text area" do
      expect_error(
        {
          rules: [
            { area: "post_headings", declarations: { "background-color" => "var(--primary)" } },
          ],
        },
        "rules[0]: text on background is",
      )
      expect(AppearanceStyles::AreaCatalog.instance.all.map(&:key)).to include("post_images")
      expect(AppearanceStyles::AreaCatalog.instance["post_images"].text_color).to be_nil
    end

    it "checks rules for the same area together when both can apply" do
      expect_error(
        {
          rules: [
            {
              area: "primary_button",
              declarations: {
                "background-color" => "light-dark(#000000, #000000)",
                "color" => "light-dark(#ffffff, #ffffff)",
              },
            },
            {
              area: "primary_button",
              media: "mobile",
              declarations: {
                "color" => "light-dark(#000000, #000000)",
              },
            },
          ],
        },
        "rules[0] and rules[1]: text on background is",
      )
    end

    it "checks the color the draft gives a token, not the default" do
      expect_error(
        { variables: { "--token-color-surface" => "var(--primary)" } },
        "--token-color-text-default on --token-color-surface is",
      )
      expect_error(
        {
          variables: {
            "--token-color-surface" => "var(--primary)",
            "--token-color-text-default" => "var(--secondary)",
          },
          rules: [
            {
              area: "primary_button",
              declarations: {
                "background-color" => "var(--token-color-surface)",
                "color" => "var(--primary)",
              },
            },
          ],
        },
        "rules[0]: text on background is",
      )
    end

    it "checks background and text variables a rule overrides" do
      expect_error(
        {
          rules: [
            {
              area: "primary_button",
              declarations: {
                "--d-button-primary-text-color" => "var(--tertiary)",
              },
            },
          ],
        },
        "rules[0]: --d-button-primary-text-color on --d-button-primary-bg-color is",
      )
    end

    it "rejects text that would be unreadable on its background" do
      unreadable = {
        rules: [
          {
            area: "primary_button",
            declarations: {
              "background-color" => "light-dark(#ffd400, #ffd400)",
              "color" => "var(--secondary)",
            },
          },
        ],
      }
      expect_error(unreadable, "text on background is")

      expect_valid(
        rules: [
          {
            area: "primary_button",
            declarations: {
              "background-color" => "light-dark(#2e7d32, #66bb6a)",
              "color" => "light-dark(#ffffff, #111111)",
            },
          },
        ],
      )
    end

    it "checks background and text variable pairs against the draft's palettes" do
      palettes = {
        "light" => ColorScheme.base_colors.merge("quaternary" => "f08c00", "secondary" => "ffffff"),
        "dark" => ColorScheme::BUILT_IN_SCHEMES[:Dark].merge("quaternary" => "f08c00"),
      }

      result =
        described_class.call(
          { variables: { "--d-button-primary-bg-color" => "var(--quaternary)" } },
          palettes:,
        )
      expect(result.errors.join).to include(
        "--d-button-primary-text-color on --d-button-primary-bg-color is",
      )

      result =
        described_class.call(
          {
            variables: {
              "--d-button-primary-bg-color" => "var(--quaternary)",
              "--d-button-primary-text-color" => "light-dark(#1a1a1a, #1a1a1a)",
            },
          },
          palettes:,
        )
      expect(result.errors).to eq([])
    end

    it "checks backgrounds without a text variable against the text core shows on them" do
      expect_error(
        { variables: { "--d-category-box-background-color" => "light-dark(#0f172a, #111827)" } },
        "--primary on --d-category-box-background-color is",
      )
      expect_valid(
        variables: {
          "--d-category-box-background-color" => "light-dark(#eef2ff, #111827)",
        },
      )
    end

    it "checks dark mode separately" do
      expect_error(
        {
          rules: [
            {
              area: "post",
              declarations: {
                "background-color" => "light-dark(#ffffff, #222222)",
                "color" => "light-dark(#111111, #333333)",
              },
            },
          ],
        },
        "in dark mode",
      )
    end

    it "checks a new background against the text color core gives the area" do
      expect_error(
        {
          rules: [
            {
              area: "header",
              declarations: {
                "background-image" => "linear-gradient(90deg, var(--tertiary), var(--quaternary))",
              },
            },
          ],
        },
        "text on background is 3.24:1 in light mode",
      )
    end

    it "only allows the configured fonts" do
      expect_error(declare("Comic Sans MS", property: "font-family"), "fonts are chosen")
      expect_valid(declare("var(--heading-font-family)", property: "font-family"))
    end

    it "rejects non-string values" do
      expect_error(
        { rules: [{ area: "post", declarations: { "color" => { "x" => 1 } } }] },
        "must be a string",
      )
    end
  end

  describe "areas" do
    it "renders alternating rows, page scoping and bounded media sizes" do
      css =
        expect_valid(
          rules: [
            {
              area: "topic_list_item",
              state: "odd",
              page: "lists",
              declarations: {
                "background-color" => "var(--primary-very-low)",
              },
            },
            { area: "category_logo", declarations: { "max-height" => "80px" } },
          ],
        )

      expect(css).to include(
        "body.navigation-topics:not(.admin-interface) .topic-list-item:nth-child(odd) {",
      )
      expect(css).to include("body:not(.admin-interface) .category-logo img {")
    end

    it "only sizes media areas, within bounds" do
      expect_error(
        { rules: [{ area: "header", declarations: { "height" => "80px" } }] },
        "property is not allowed",
      )
      expect_error(
        { rules: [{ area: "category_logo", declarations: { "height" => "2000px" } }] },
        "outside 16px to 480px",
      )
    end

    it "rejects states an area doesn't have" do
      expect_error(
        { rules: [{ area: "post", state: "odd", declarations: { "color" => "var(--primary)" } }] },
        "state \"odd\" is not allowed",
      )
    end
  end

  describe "contrast with derived shades" do
    it "resolves shades core derives from the palette" do
      expect_error(
        {
          rules: [
            {
              area: "post",
              declarations: {
                "background-color" => "var(--primary-low)",
                "color" => "var(--primary-low-mid)",
              },
            },
          ],
        },
        "text on background is",
      )

      expect_valid(
        rules: [
          {
            area: "post",
            declarations: {
              "background-color" => "var(--primary-very-low)",
              "color" => "var(--primary-high)",
            },
          },
        ],
      )
    end

    it "resolves color-mix() in srgb" do
      expect_error(
        {
          rules: [
            {
              area: "post",
              declarations: {
                "background-color" => "color-mix(in srgb, var(--secondary) 50%, var(--primary))",
                "color" => "var(--primary)",
              },
            },
          ],
        },
        "text on background is",
      )
    end

    it "checks against the palettes it is given" do
      dark_text = {
        rules: [
          {
            area: "header",
            declarations: {
              "background-color" => "var(--header_background)",
              "color" => "var(--header_primary-low-mid)",
            },
          },
        ],
      }
      palettes = {
        "light" => {
          "header_background" => "ffffff",
          "header_primary" => "333333",
        },
        "dark" => {
          "header_background" => "111111",
          "header_primary" => "dddddd",
        },
      }
      expect(described_class.call(dark_text, palettes:).errors.join).to include(
        "text on background is",
      )
    end
  end
end
