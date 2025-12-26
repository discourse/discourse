import Component from "@glimmer/component";
import { service } from "@ember/service";
import DToast from "discourse/float-kit/components/d-toast";

const MAX_VISIBLE_TOASTS = 3;

/**
 * The container component for all toasts.
 * Renders the last N active toasts.
 *
 * @component d-toasts
 */
export default class DToasts extends Component {
  @service toasts;

  /**
   * Returns the subset of toasts that should be visible in the UI.
   *
   * @returns {Array<DToastInstance>}
   */
  get visibleToasts() {
    return this.toasts.activeToasts.slice(-MAX_VISIBLE_TOASTS);
  }

  <template>
    <section class="fk-d-toasts" aria-label="Notifications">
      {{#each this.visibleToasts key="id" as |toast|}}
        <DToast @toasts={{this.toasts.activeToasts}} @toast={{toast}} />
      {{/each}}
    </section>
  </template>
}
