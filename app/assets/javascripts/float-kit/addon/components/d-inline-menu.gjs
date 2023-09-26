import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import DInlineFloat from "float-kit/components/d-inline-float";
import { MENU } from "float-kit/lib/constants";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";

export default class DInlineMenu extends Component {
  <template>
    {{! template-lint-disable modifier-name-case }}
    <div
      id={{MENU.portalOutletId}}
      {{didInsert this.menu.registerPortalOutletElement}}
    ></div>

    <DInlineFloat
      @instance={{this.menu.activeMenu}}
      @portalOutletElement={{this.menu.portalOutletElement}}
      @trapTab={{this.menu.activeMenu.options.trapTab}}
      @mainClass="fk-d-menu"
      @innerClass="fk-d-menu__inner-content"
      @role="dialog"
      @inline={{@inline}}
    />
  </template>

  @service menu;
}
