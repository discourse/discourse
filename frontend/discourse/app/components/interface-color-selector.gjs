import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

export default class InterfaceColorSelector extends Component {
  @service interfaceColor;

  get selectorIcon() {
    if (this.interfaceColor.lightModeForced) {
      return "sun";
    } else if (this.interfaceColor.darkModeForced) {
      return "moon";
    } else {
      return "circle-half-stroke";
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
  </template>
}
