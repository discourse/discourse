import Component from "@glimmer/component";
import { service } from "@ember/service";
import DToast from "float-kit/components/d-toast";

export default class DToasts extends Component {
  @service toasts;

  <template>
    <section class="fk-d-toasts">
      {{#each this.toasts.activeToasts as |toast|}}
        <DToast @toast={{toast}} />
      {{/each}}
    </section>
  </template>
}
