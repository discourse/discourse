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
 * Admin settings for the category list, reached from the list itself.
 */
export default class CategoryListSettingsMenu extends Component {
  @service siteSettings;

  get pageLayoutURL() {
    return getURL(PAGE_LAYOUT_SETTINGS_URL);
  }

  // A custom order only applies with fixed positions, so choosing to
  // reorder turns them on, and back off if no order is saved
  @action
  async reorder(menu) {
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
    <DMenu
      @ariaLabel={{i18n "categories.settings"}}
      @icon="gear"
      @identifier="category-list-settings"
      @modalForMobile={{true}}
      @triggerClass="btn-default category-list-settings__trigger"
    >
      <:content as |menu|>
        <DDropdownMenu as |dropdown|>
          <dropdown.item>
            <DButton
              class="btn-transparent category-list-settings__reorder"
              @action={{fn this.reorder menu}}
              @icon="shuffle"
              @label="categories.reorder.title"
            />
          </dropdown.item>
          <dropdown.item>
            <DButton
              class="btn-transparent category-list-settings__page-layout"
              @href={{this.pageLayoutURL}}
              @icon="table-columns"
              @label="categories.page_layout"
            />
          </dropdown.item>
        </DDropdownMenu>
      </:content>
    </DMenu>
  </template>
}
