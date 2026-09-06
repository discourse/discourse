import Component from "@glimmer/component";
import { service } from "@ember/service";
import DToast from "discourse/float-kit/components/d-toast";
import type ToastsService from "discourse/float-kit/services/toasts";

/**
 * The app-root host for toasts, mounted once. It renders a `DToast` for every
 * toast currently active in the `toasts` service, stacked in a fixed container.
 */
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
