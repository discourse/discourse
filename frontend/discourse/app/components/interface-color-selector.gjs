import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DSelect from "discourse/ui-kit/select/d-select";
import { selectOption } from "discourse/ui-kit/select/select-engine";
import { i18n } from "discourse-i18n";

const MODES = [
  { id: "light", icon: "sun" },
  { id: "dark", icon: "moon" },
  { id: "auto", icon: "circle-half-stroke" },
];

export default class InterfaceColorSelector extends Component {
  @service interfaceColor;
  @service siteSettings;

  /** The mode in use: a forced light or dark mode, otherwise `"auto"`. */
  get currentMode() {
    if (this.interfaceColor.lightModeForced) {
      return "light";
    } else if (this.interfaceColor.darkModeForced) {
      return "dark";
    } else {
      return "auto";
    }
  }

  get selectorIcon() {
    return MODES.find((mode) => mode.id === this.currentMode).icon;
  }

  /** The modes as options, with their names translated. */
  get modeOptions() {
    return MODES.map((mode) =>
      selectOption(mode, {
        label: i18n(`sidebar.footer.interface_color_selector.${mode.id}`),
      })
    );
  }

  @action
  changeMode(mode) {
    if (mode === "light") {
      this.interfaceColor.forceLightMode();
    } else if (mode === "dark") {
      this.interfaceColor.forceDarkMode();
    } else if (mode === "auto") {
      this.interfaceColor.useAutoMode();
    }
  }

  @action
  switchToLight(dMenu) {
    this.interfaceColor.forceLightMode();
    dMenu.close();
  }

  @action
  switchToDark(dMenu) {
    this.interfaceColor.forceDarkMode();
    dMenu.close();
  }

  @action
  switchToAuto(dMenu) {
    this.interfaceColor.useAutoMode();
    dMenu.close();
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
    {{#if this.siteSettings.enable_new_select_controls}}
      <DSelect
        class="interface-color-selector icon sidebar-footer-actions-button"
        title={{i18n "sidebar.footer.interface_color_selector.title"}}
        @clearMode="never"
        @icon={{this.selectorIcon}}
        @iconField="icon"
        @iconOnly={{true}}
        @identifier="interface-color-selector"
        @onChange={{this.changeMode}}
        @options={{this.modeOptions}}
        @selectedIcon="check"
        @showCaret={{false}}
        @texts={{hash
          ariaLabel=(i18n "sidebar.footer.interface_color_selector.title")
        }}
        @value={{this.currentMode}}
        @variant="static"
      />
    {{else}}
      <DMenu
        class="interface-color-selector icon"
        data-current-mode={{this.interfaceColor.colorMode}}
        @animated={{false}}
        @ariaLabel={{i18n
          "sidebar.footer.interface_color_selector.aria_label"
          mode=this.interfaceColor.colorMode
        }}
        @icon={{this.selectorIcon}}
        @identifier="interface-color-selector"
        @title={{i18n "sidebar.footer.interface_color_selector.title"}}
        @triggerClass="btn-flat sidebar-footer-actions-button"
      >
        <:content as |dMenu|>
          <DDropdownMenu as |dropdown|>
            <dropdown.item>
              <DButton
                class="interface-color-selector__light-option"
                @action={{fn this.switchToLight dMenu}}
                @icon="sun"
                @translatedLabel={{i18n
                  "sidebar.footer.interface_color_selector.light"
                }}
              />
            </dropdown.item>
            <dropdown.item>
              <DButton
                class="interface-color-selector__dark-option"
                @action={{fn this.switchToDark dMenu}}
                @icon="moon"
                @translatedLabel={{i18n
                  "sidebar.footer.interface_color_selector.dark"
                }}
              />
            </dropdown.item>
            <dropdown.item>
              <DButton
                class="interface-color-selector__auto-option"
                @action={{fn this.switchToAuto dMenu}}
                @icon="circle-half-stroke"
                @translatedLabel={{i18n
                  "sidebar.footer.interface_color_selector.auto"
                }}
              />
            </dropdown.item>
          </DDropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
