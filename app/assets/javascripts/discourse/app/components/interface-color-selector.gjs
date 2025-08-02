import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

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
    this.interfaceColor.removeColorModeOverride();
    dMenu.close();
  }

  <template>
    <DMenu
      @icon={{this.selectorIcon}}
      @triggerClass="btn-flat sidebar-footer-actions-button"
      @identifier="interface-color-selector"
      @animated={{false}}
      class="interface-color-selector icon"
    >
      <:content as |dMenu|>
        <DropdownMenu as |dropdown|>
          <dropdown.item>
            <DButton
              class="btn-default interface-color-selector__light-option"
              @icon="sun"
              @translatedLabel={{i18n
                "sidebar.footer.interface_color_selector.light"
              }}
              @action={{fn this.switchToLight dMenu}}
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              class="btn-default interface-color-selector__dark-option"
              @icon="moon"
              @translatedLabel={{i18n
                "sidebar.footer.interface_color_selector.dark"
              }}
              @action={{fn this.switchToDark dMenu}}
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              class="btn-default interface-color-selector__auto-option"
              @icon="circle-half-stroke"
              @translatedLabel={{i18n
                "sidebar.footer.interface_color_selector.auto"
              }}
              @action={{fn this.switchToAuto dMenu}}
            />
          </dropdown.item>
        </DropdownMenu>
      </:content>
    </DMenu>
  </template>
}
