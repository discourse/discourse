import Component from "@glimmer/component";
import { service } from "@ember/service";
import DHeadlessMenu from "float-kit/components/d-headless-menu";

export default class DMenus extends Component {
  @service menu;

  <template>
    <div id="d-menu-portals"></div>

    {{#each this.menu.registeredMenus key="id" as |menu|}}
      {{#if menu.detachedTrigger}}
        <DHeadlessMenu @menu={{menu}} />
      {{/if}}
    {{/each}}
  </template>
}
