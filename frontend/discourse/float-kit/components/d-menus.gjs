import Component from "@glimmer/component";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { service } from "@ember/service";
import DHeadlessMenu from "discourse/float-kit/components/d-headless-menu";

export default class DMenus extends Component {
  @service menu;
  @service sheetLayerStore;

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
