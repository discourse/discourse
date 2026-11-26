import Component from "@glimmer/component";
import { service } from "@ember/service";
import BlockOutlet from "discourse/blocks/block-outlet";
import lazyHash from "discourse/helpers/lazy-hash";

export default class ContextCategory extends Component {
  @service pageShell;

  <template>
    {{#let this.pageShell.contextCategory as |category|}}
      <div class="context-category">
        <h2>{{category.displayName}}</h2>
        {{#if category.descriptionText}}
          <p
            class="context-category__description"
          >{{category.descriptionText}}</p>
        {{/if}}
        <BlockOutlet
          @name="category-guide"
          @outletArgs={{lazyHash category=category}}
        />
      </div>
    {{/let}}
  </template>
}
