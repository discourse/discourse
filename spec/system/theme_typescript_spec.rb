# frozen_string_literal: true

describe "Theme TypeScript support" do
  it "compiles and runs a theme .gts file authored in TypeScript" do
    theme = Fabricate(:theme, name: "TypeScript Theme")
    theme.set_field(
      target: :extra_js,
      type: :js,
      name: "discourse/connectors/below-footer/typescript-proof.gts",
      value: <<~GTS,
        import Component from "@glimmer/component";

        interface Rgb {
          r: number;
          g: number;
          b: number;
        }

        function toCss({ r, g, b }: Rgb): string {
          return `rgb(${r}, ${g}, ${b})`;
        }

        export default class TypescriptProof extends Component {
          color: Rgb = { r: 0, g: 128, b: 0 };

          get label(): string {
            return toCss(this.color);
          }

          <template>
            <div class="ts-theme-proof">{{this.label}}</div>
          </template>
        }
      GTS
    )
    theme.save!
    SiteSetting.default_theme_id = theme.id

    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".ts-theme-proof").filter(visible: true),
    ).to PlaywrightMatchers.contain_text(
      [browser_text_pattern("rgb(0, 128, 0)")],
      useInnerText: true,
    )
  end
end
