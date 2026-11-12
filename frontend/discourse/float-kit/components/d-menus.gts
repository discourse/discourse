import Component from "@glimmer/component";
import { service } from "@ember/service";
import DHeadlessMenu from "discourse/float-kit/components/d-headless-menu";
import type MenuService from "discourse/float-kit/services/menu";

/**
 * The app-root host for service-driven menus, mounted once. It provides the
 * portal outlet that menus teleport their content into, and renders a
 * `DHeadlessMenu` for every menu registered with the `menu` service whose
 * trigger is detached (i.e. created through the service rather than by `DMenu`).
 */
export default class DMenus extends Component {
  @service declare menu: MenuService;

  <template>
    <div id="d-menu-portals"></div>

    {{#each this.menu.registeredMenus key="id" as |menu|}}
      {{#if menu.detachedTrigger}}
        <DHeadlessMenu @menu={{menu}} />
      {{/if}}
    {{/each}}
  </template>
}
