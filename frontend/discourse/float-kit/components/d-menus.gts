import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DHeadlessMenu from "discourse/float-kit/components/d-headless-menu";
import type MenuService from "discourse/float-kit/services/menu";
import type SheetLayerStore from "discourse/float-kit/services/sheet-layer-store";

/**
 * The app-root host for service-driven menus, mounted once. It provides the
 * portal outlet that menus teleport their content into, and renders a
 * `DHeadlessMenu` for every menu registered with the `menu` service whose
 * trigger is detached (i.e. created through the service rather than by `DMenu`).
 */
export default class DMenus extends Component {
  @service declare menu: MenuService;
  @service declare sheetLayerStore: SheetLayerStore;

  <template>
    <div
      id="d-menu-portals"
      {{didInsert this.sheetLayerStore.registerAutomaticLayerElement}}
      {{willDestroy this.sheetLayerStore.unregisterAutomaticLayerElement}}
    ></div>

    {{#each this.menu.registeredMenus key="id" as |menu|}}
      {{#if menu.detachedTrigger}}
        <DHeadlessMenu @menu={{menu}} />
      {{/if}}
    {{/each}}
  </template>
}
