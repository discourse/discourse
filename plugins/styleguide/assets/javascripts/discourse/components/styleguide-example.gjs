import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DHighlightedCode from "discourse/ui-kit/d-highlighted-code";

export default class StyleguideExample extends Component {
  @tracked value = null;
  @tracked showCode = false;

  constructor() {
    super(...arguments);
    this.value = this.args.initialValue;
  }

  <template>
    <section class="styleguide-example">
      <div class="example-title">
        <div class="example-title--text">
          {{@title}}
        </div>

        {{#if @code}}
          <DButton
            @icon="code"
            @action={{fn (mut this.showCode) (not this.showCode)}}
            class="btn-flat btn-transparent"
          />
        {{/if}}
      </div>

      {{#if this.showCode}}
        <div class="styleguide-code">
          <DHighlightedCode @code={{@code}} @lang="javascript" />
        </div>
      {{/if}}

      <section class="rendered">{{yield this.value}}</section>
    </section>
  </template>
}
