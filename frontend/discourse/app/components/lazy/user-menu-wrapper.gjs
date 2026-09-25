import Component from "@glimmer/component";
import DAsyncContent from "discourse/ui-kit/d-async-content";

let load;

export default class LazyUserMenuWrapper extends Component {
  get component() {
    return (load ??= import("discourse/components/header/user-menu-wrapper"));
  }

  <template>
    <DAsyncContent @asyncData={{this.component}}>
      <:loading></:loading>
      <:content as |module|>
        <module.default @toggleUserMenu={{@toggleUserMenu}} ...attributes />
      </:content>
    </DAsyncContent>
  </template>
}
