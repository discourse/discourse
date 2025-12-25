import Component from "@glimmer/component";
import { service } from "@ember/service";
import DToast from "discourse/float-kit/components/d-toast";

export default class DToasts extends Component {
  @service toasts;

  get visibleToasts() {
    return this.toasts.activeToasts.slice(-3);
  }

  <template>
    <section class="fk-d-toasts">
      {{#each this.visibleToasts key="id" as |toast|}}
        <DToast
          @toasts={{this.toasts.activeToasts}}
          @toast={{toast}}
        />
      {{/each}}
    </section>
  </template>
}
