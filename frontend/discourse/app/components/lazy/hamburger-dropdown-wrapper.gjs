import Component from "@glimmer/component";
import DAsyncContent from "discourse/ui-kit/d-async-content";

let load;

export default class LazyHamburgerDropdownWrapper extends Component {
  get component() {
    return (load ??=
      import("discourse/components/header/hamburger-dropdown-wrapper"));
  }

  <template>
    <DAsyncContent @asyncData={{this.component}}>
      <:loading></:loading>
      <:content as |module|>
        <module.default
          ...attributes
          @sidebarEnabled={{@sidebarEnabled}}
          @toggleNavigationMenu={{@toggleNavigationMenu}}
        />
      </:content>
    </DAsyncContent>
  </template>
}
