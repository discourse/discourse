import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { inject as service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";

export default class DToasts extends Component {
  @service toasts;

  <template>
    <section class="fk-d-toasts">
      {{#each this.toasts.activeToasts as |toast|}}
        <output
          role={{if toast.options.autoClose "status" "log"}}
          key={{toast.id}}
          class={{concatClass "fk-d-toast" toast.options.class}}
          {{(if toast.options.autoClose (modifier toast.registerAutoClose))}}
          {{on "mouseenter" toast.cancelAutoClose}}
          {{on "mouseleave" toast.resumeAutoClose}}
        >
          <toast.options.component
            @data={{toast.options.data}}
            @close={{toast.close}}
          />
        </output>
      {{/each}}
    </section>
  </template>
}
