import Component from "@glimmer/component";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { cancel } from "@ember/runloop";
import { service } from "@ember/service";
import discourseLater from "discourse/lib/later";
import { ADMIN_PANEL } from "discourse/lib/sidebar/panels";
import { i18n } from "discourse-i18n";

export default class FilterNoResults extends Component {
  @service sidebarState;
  @service currentUser;
  @service router;

  redirectTimer = null;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.redirectTimer) {
      cancel(this.redirectTimer);
    }
  }

  get shouldDisplay() {
    return (
      this.sidebarState.currentPanel.filterable &&
      !!(this.args.sections?.length === 0)
    );
  }

  get noResultsDescription() {
    return this.sidebarState.currentPanel.filterNoResultsDescription(
      this.sidebarState.filter
    );
  }

  @action
  possiblyRedirect() {
    if (this.redirectTimer) {
      cancel(this.redirectTimer);
    }

    // We should probably have this admin-specific logic elsewhere,
    // but this will do for now as an experiment.
    if (
      this.sidebarState.currentPanel?.key === ADMIN_PANEL &&
      this.sidebarState.filter.includes("_") &&
      this.currentUser?.use_admin_sidebar
    ) {
      this.redirectTimer = discourseLater(() => {
        if (this.isDestroying || this.isDestroyed) {
          return;
        }

        this.router.transitionTo("adminSiteSettings", {
          queryParams: { filter: this.sidebarState.filter },
        });
      }, 1000);
    }
  }

  <template>
    {{#if this.shouldDisplay}}
      <div
        class="sidebar-no-results"
        {{didUpdate this.possiblyRedirect this.sidebarState.filter}}
      >
        <h4 class="sidebar-no-results__title">{{i18n
            "sidebar.no_results.title"
          }}</h4>
        {{#if this.noResultsDescription}}
          <p class="sidebar-no-results__description">
            {{this.noResultsDescription}}
          </p>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
