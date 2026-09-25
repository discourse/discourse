import Component from "@glimmer/component";
import DAsyncContent from "discourse/ui-kit/d-async-content";

let load;

export default class LazySearchMenuWrapper extends Component {
  get component() {
    return (load ??= import("discourse/components/header/search-menu-wrapper"));
  }

  <template>
    <DAsyncContent @asyncData={{this.component}}>
      <:loading></:loading>
      <:content as |module|>
        <module.default
          @closeSearchMenu={{@closeSearchMenu}}
          @searchInputId={{@searchInputId}}
          ...attributes
        />
      </:content>
    </DAsyncContent>
  </template>
}
