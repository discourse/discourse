import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DHighlightedCode from "discourse/ui-kit/d-highlighted-code";

export default class StyleguideExample extends Component {
  @tracked showCode = false;

  @action
  toggleCode() {
    this.showCode = !this.showCode;
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
            @action={{this.toggleCode}}
            class="btn-flat btn-transparent"
          />
        {{/if}}
      </div>

      {{#if this.showCode}}
        <div class="styleguide-code">
          <DHighlightedCode @code={{@code}} @lang="javascript" />
        </div>
      {{/if}}

      <section class="rendered">{{yield}}</section>
    </section>
  </template>
}
