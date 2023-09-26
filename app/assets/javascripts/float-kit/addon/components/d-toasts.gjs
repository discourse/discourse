import Component from "@glimmer/component";
import { inject as service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import { on } from "@ember/modifier";

export default class DToasts extends Component {
  <template>
    <div class="fk-d-toasts">
      {{#each this.toasts.activeToasts as |toast|}}
        <div
          role={{if toast.options.autoClose "status" "log"}}
          key={{toast.id}}
          class={{concatClass "fk-d-toast" toast.options.class}}
          {{(if toast.options.autoClose (modifier toast.registerAutoClose))}}
          {{on "mouseenter" toast.cancelAutoClose}}
        >
          <toast.options.component
            @data={{toast.options.data}}
            @close={{toast.close}}
          />
        </div>
      {{/each}}
    </div>
  </template>

  @service toasts;
}
