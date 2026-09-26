import Component from "@glimmer/component";
import { _hasLayout } from "discourse/lib/blocks/-internals/outlet-layouts";
import DAsyncContent from "discourse/ui-kit/d-async-content";

let load;

// The block system only loads once a layout is registered for an outlet.
export default class LazyBlockOutlet extends Component {
  get hasLayout() {
    return _hasLayout(this.args.name);
  }

  get component() {
    return (load ??= import("discourse/blocks/block-outlet"));
  }

  <template>
    {{#if this.hasLayout}}
      <DAsyncContent @asyncData={{this.component}}>
        <:loading></:loading>
        <:content as |module|>
          <module.default
            @name={{@name}}
            @outletArgs={{@outletArgs}}
            @deprecatedArgs={{@deprecatedArgs}}
          >
            <:before as |hasLayout|>{{yield hasLayout to="before"}}</:before>
            <:after as |hasLayout|>{{yield hasLayout to="after"}}</:after>
            <:error as |error|>{{yield error to="error"}}</:error>
          </module.default>
        </:content>
      </DAsyncContent>
    {{else}}
      {{yield false to="before"}}
      {{yield false to="after"}}
    {{/if}}
  </template>
}
