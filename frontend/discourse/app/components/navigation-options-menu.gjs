import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import { i18n } from "discourse-i18n";

const PAGE_LAYOUT_SETTINGS_URL =
  "/admin/config/category-management/settings?filter=category_page_style";

/**
 * A list's less frequent actions, gathered behind one button beside its views
 * in the mobile tab bar: bulk select on topic lists, and on the category list
 * reordering (`@canReorderCategories`) and its site settings
 * (`@canChangeCategorySettings`).
 */
export default class NavigationOptionsMenu extends Component {
  @service siteSettings;

  get hasOptions() {
    return (
      this.args.showBulkSelect ||
      this.args.canReorderCategories ||
      this.args.canChangeCategorySettings
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

  // A custom order only applies with fixed positions, so choosing to
  // reorder turns them on, and back off if no order is saved
  @action
  async reorderCategories(menu) {
    await menu.close();

    const fixesPositions = !this.siteSettings.fixed_category_positions;

    if (fixesPositions) {
      try {
        await this.#setFixedPositions(true);
      } catch (error) {
        popupAjaxError(error);
        return;
      }
    }

    await this.args.reorderCategories();

    // Saving an order reloads the page, so the modal closing means none was
    if (fixesPositions) {
      try {
        await this.#setFixedPositions(false);
      } catch (error) {
        popupAjaxError(error);
      }
    }
  }

  async #setFixedPositions(value) {
    await ajax("/admin/site_settings/fixed_category_positions", {
      type: "PUT",
      data: { fixed_category_positions: value },
    });
    this.siteSettings.fixed_category_positions = value;
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
