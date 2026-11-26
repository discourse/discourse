import Component from "@glimmer/component";
import { service } from "@ember/service";
import BlockOutlet from "discourse/blocks/block-outlet";
import ContextCategoryNavigation from "discourse/components/page-shell/context-category-navigation";
import lazyHash from "discourse/helpers/lazy-hash";

export default class ContextCategory extends Component {
  @service pageShell;

  <template>
    {{#let this.pageShell.contextCategory as |category|}}
      <div class="context-category">
        <ContextCategoryNavigation @category={{category}} />
        <BlockOutlet
          @name="category-guide"
          @outletArgs={{lazyHash category=category}}
        />
      </div>
    {{/let}}
  </template>
}
