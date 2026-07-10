import Component from "@glimmer/component";
import { service } from "@ember/service";
import DHeadlessMenu from "discourse/float-kit/components/d-headless-menu";
import type MenuService from "discourse/float-kit/services/menu";

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
