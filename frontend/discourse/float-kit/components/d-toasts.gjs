import Component from "@glimmer/component";
import { service } from "@ember/service";
import DToast from "discourse/float-kit/components/d-toast";

export default class DToasts extends Component {
  @service toasts;

  <template>
    <section class="fk-d-toasts">
      {{#each this.toasts.activeToasts key="id" as |toast index|}}
        <DToast
          @toasts={{this.toasts.activeToasts}}
          @toast={{toast}}
          @index={{index}}
        />
      {{/each}}
    </section>
  </template>
}
