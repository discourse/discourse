# frozen_string_literal: true

describe "Cross theme imports", type: :system do
  let!(:theme_1) { Fabricate(:theme, name: "Theme 1") }

  let!(:theme_2) { Fabricate(:theme, name: "Theme 2", component: true) }

  before do
    theme_1.set_field(
      target: :extra_js,
      type: :js,
      name: "discourse/initializers/init-one.js",
      value: <<~JS,
        import { HELLO_TWO } from "discourse/theme-#{theme_2.id}/discourse/initializers/init-two";

        //import { discourse_initializers_init_two } from "discourse/theme-#{theme_2.id}";
      // const { HELLO_TWO } = discourse_initializers_init_two;

        export const HELLO = "hello from theme 1";
        export default {
          initialize(){
            console.log("Theme 1 JS loaded and received:", HELLO_TWO);
          }
        }
    JS
    )
    theme_1.save!
    SiteSetting.default_theme_id = theme_1.id

    theme_2.set_field(
      target: :extra_js,
      type: :js,
      name: "discourse/initializers/init-two.js",
      value: <<~JS,
        import TheDefault, { HELLO } from "discourse/theme-#{theme_1.id}/discourse/initializers/init-one";

        //import Theme1Modules from "discourse/theme-#{theme_1.id}";
        //import { discourse_initializers_init_one } from "discourse/theme-#{theme_1.id}";
        //const { HELLO } = discourse_initializers_init_one;
        // const { HELLO } = Theme1Modules["discourse/initializers/init-one"];
        //const face = discourse_initializers_init_one;

        export const HELLO_TWO = "hello from theme 2";
        export default {
          initialize(){
            console.log("Theme 2 JS loaded and received:", HELLO);
            console.log(TheDefault)
          }
        }
      JS
    )
    theme_2.save!

    theme_1.add_relative_theme!(:child, theme_2)
    theme_1.save!
  end

  it "works" do
    visit "/"
    pause_test
  end
end
