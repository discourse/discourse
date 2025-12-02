import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import HighlightedCode from "discourse/admin/components/highlighted-code";

export default class StyleguideExample extends Component {
  @tracked value = null;

  constructor() {
    super(...arguments);
    this.value = this.args.initialValue;
  }

  <template>
    <section class="styleguide-example">
      <div class="example-title">{{@title}}</div>

      {{#if @code}}
        <HighlightedCode @code={{@code}} @lang="javascript" />
      {{/if}}

      <section class="rendered">{{yield this.value}}</section>
    </section>
  </template>
}
