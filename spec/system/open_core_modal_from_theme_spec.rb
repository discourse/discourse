# frozen_string_literal: true

RSpec.describe "Open core modal from theme" do
  fab!(:theme)

  before { SiteSetting.default_theme_id = theme.id }

  it "opens a core modal the theme imports statically" do
    theme.set_field(
      target: :extra_js,
      type: :js,
      name: "discourse/connectors/above-main-container/open-core-modal.gjs",
      value: <<~JS,
        import Component from "@glimmer/component";
        import { action } from "@ember/object";
        import { service } from "@ember/service";
        import { CLOSE_STATUS_TYPE } from "discourse/components/modal/edit-topic-timer";
        import FullscreenCode from "discourse/components/modal/fullscreen-code";
        import DButton from "discourse/ui-kit/d-button";

        export default class OpenCoreModal extends Component {
          @service modal;

          @action
          open() {
            this.modal.show(FullscreenCode, {
              model: { code: `status: ${CLOSE_STATUS_TYPE}`, codeClasses: "text" },
            });
          }

          <template>
            <DButton class="open-core-modal" @action={{this.open}} @translatedLabel="Open" />
          </template>
        }
      JS
    )
    theme.save!

    visit("/")
    find(".open-core-modal").click

    expect(page).to have_css(".fullscreen-code-modal code", text: "status: close")
  end

  it "applies the theme's class customization when the modal loads" do
    theme.set_field(
      target: :extra_js,
      type: :js,
      name: "discourse/api-initializers/customize-shortcuts-help.js",
      value: <<~JS,
        import { apiInitializer } from "discourse/lib/api";

        export default apiInitializer((api) => {
          api.modifyClass(
            "component:modal/keyboard-shortcuts-help",
            (Superclass) =>
              class extends Superclass {
                get shortcuts() {
                  const shortcuts = super.shortcuts;
                  shortcuts.application.shortcuts.theme_shortcut = {
                    keys1: "alt+t",
                    description: "Shortcut added by theme",
                    shortcutTexts: ["Alt T"],
                  };
                  return shortcuts;
                }
              }
          );
        });
      JS
    )
    theme.save!

    visit("/")
    page.send_keys("?")

    expect(page).to have_css(".keyboard-shortcuts-modal", text: "Shortcut added by theme")
  end
end
