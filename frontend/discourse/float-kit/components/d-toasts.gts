import Component from "@glimmer/component";
import { service } from "@ember/service";
import DToast from "discourse/float-kit/components/d-toast";
import type ToastsService from "discourse/float-kit/services/toasts";

export default class DToasts extends Component {
  @service declare toasts: ToastsService;

  <template>
    <section class="fk-d-toasts">
      {{#each this.toasts.activeToasts as |toast|}}
        <DToast @toast={{toast}} />
      {{/each}}
    </section>
  </template>
}
