import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import getURL from "discourse/lib/get-url";
import {
  canDismissNewAndStopTracking,
  dismissNewLabel,
  dismissNewOptions,
  dismissReadLabel,
  newListSubset,
  showDismissReadModal,
} from "discourse/lib/topic-dismiss";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

const PAGE_LAYOUT_SETTINGS_URL =
  "/admin/config/category-management/settings?filter=category_page_style";

/**
 * A list's actions, gathered behind one button beside its views in the mobile
 * tab bar: on topic lists dismissing (`@showDismissRead`, `@showResetNew`) and
 * bulk select, and on the category list reordering (`@canReorderCategories`)
 * and its site settings (`@canChangeCategorySettings`).
 */
export default class NavigationOptionsMenu extends Component {
  @service currentUser;
  @service modal;
  @service siteSettings;

  get hasOptions() {
    return (
      this.args.showDismissRead ||
      this.args.showResetNew ||
      this.args.showBulkSelect ||
      this.args.canReorderCategories ||
      this.args.canChangeCategorySettings
    );
  }

  get selectedCount() {
    return this.args.bulkSelectHelper?.selected.length ?? 0;
  }

  get newListSubset() {
    return newListSubset(this.args.model);
  }

  get dismissReadLabel() {
    return dismissReadLabel(this.selectedCount);
  }

  get dismissNewLabel() {
    return dismissNewLabel({
      unifiedNew: this.currentUser?.unified_new_enabled,
      subset: this.newListSubset,
      selectedCount: this.selectedCount,
    });
  }

  get showDismissNewAndStopTracking() {
    return (
      this.args.showNewDismissCombo &&
      canDismissNewAndStopTracking(this.newListSubset)
    );
  }

  get pageLayoutURL() {
    return getURL(PAGE_LAYOUT_SETTINGS_URL);
  }

  @action
  run(option, menu) {
    menu.close();
    option();
  }

  @action
  dismissRead(menu) {
    menu.close();
    showDismissReadModal(this.modal, {
      selectedCount: this.selectedCount,
      dismissRead: this.args.dismissRead,
    });
  }

  // Only the combined new list dismisses by what's showing
  @action
  dismissNew(menu, untrack = false) {
    menu.close();

    if (this.args.showNewDismissCombo) {
      this.args.resetNew({ ...dismissNewOptions(this.newListSubset), untrack });
    } else {
      this.args.resetNew();
    }
  }

  @action
  async reorderCategories(menu) {
    await menu.close();
    this.args.reorderCategories({
      enableFixedPositions: !this.siteSettings.fixed_category_positions,
    });
  }

  <template>
    {{#if this.hasOptions}}
      <DMenu
        @ariaLabel={{i18n "topics.list_options"}}
        @icon="ellipsis-vertical"
        @identifier="navigation-options"
        @modalForMobile={{true}}
        @triggerClass="btn-transparent navigation-options__trigger"
      >
        <:content as |menu|>
          <DDropdownMenu as |dropdown|>
            {{#if @showDismissRead}}
              <dropdown.item>
                <DButton
                  class="btn-transparent navigation-options__dismiss-read"
                  @action={{fn this.dismissRead menu}}
                  @icon="check"
                  @title="topics.bulk.dismiss_tooltip"
                  @translatedLabel={{this.dismissReadLabel}}
                />
              </dropdown.item>
            {{/if}}
            {{#if @showResetNew}}
              <dropdown.item>
                <DButton
                  class="btn-transparent navigation-options__dismiss-new"
                  @action={{fn this.dismissNew menu false}}
                  @icon="check"
                  @translatedLabel={{this.dismissNewLabel}}
                />
              </dropdown.item>
              {{#if this.showDismissNewAndStopTracking}}
                <dropdown.item>
                  <DButton
                    class="btn-transparent navigation-options__dismiss-new-stop-tracking"
                    @action={{fn this.dismissNew menu true}}
                    @icon="bell-slash"
                    @label="topics.bulk.dismiss_and_stop_tracking"
                  />
                </dropdown.item>
              {{/if}}
            {{/if}}
            {{#if @showBulkSelect}}
              <dropdown.item>
                <DButton
                  class="btn-transparent navigation-options__bulk-select"
                  @action={{fn
                    this.run
                    @bulkSelectHelper.toggleBulkSelect
                    menu
                  }}
                  @icon="list"
                  @label="topics.bulk.select"
                />
              </dropdown.item>
            {{/if}}
            {{#if @canReorderCategories}}
              <dropdown.item>
                <DButton
                  class="btn-transparent navigation-options__reorder-categories"
                  @action={{fn this.reorderCategories menu}}
                  @icon="shuffle"
                  @label="categories.reorder.title"
                />
              </dropdown.item>
            {{/if}}
            {{#if @canChangeCategorySettings}}
              <dropdown.item>
                <DButton
                  class="btn-transparent navigation-options__page-layout"
                  @href={{this.pageLayoutURL}}
                  @icon="table-columns"
                  @label="categories.page_layout"
                />
              </dropdown.item>
            {{/if}}
          </DDropdownMenu>
        </:content>
      </DMenu>
    {{/if}}
  </template>
}
