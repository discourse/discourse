import Component from "@glimmer/component";
import { fn, get } from "@ember/helper";
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

export default class NavigationOptionsMenu extends Component {
  @service currentUser;
  @service modal;
  @service siteSettings;

  get options() {
    const options = [];
    const selectedCount = this.args.bulkSelectHelper?.selected.length ?? 0;

    if (this.args.showDismissRead) {
      options.push({
        id: "dismiss-read",
        icon: "check",
        label: dismissReadLabel(selectedCount),
        title: i18n("topics.bulk.dismiss_tooltip"),
        action: () =>
          showDismissReadModal(this.modal, {
            selectedCount,
            dismissRead: this.args.dismissRead,
          }),
      });
    }

    if (this.args.showResetNew) {
      const subset = newListSubset(this.args.model);
      const dismissNew = (untrack) => {
        if (this.args.showNewDismissCombo) {
          this.args.resetNew({ ...dismissNewOptions(subset), untrack });
        } else {
          this.args.resetNew();
        }
      };

      options.push({
        id: "dismiss-new",
        icon: "check",
        label: dismissNewLabel({
          unifiedNew: this.currentUser?.unified_new_enabled,
          subset,
          selectedCount,
        }),
        action: () => dismissNew(false),
      });

      if (
        this.args.showNewDismissCombo &&
        canDismissNewAndStopTracking(subset)
      ) {
        options.push({
          id: "dismiss-new-stop-tracking",
          icon: "bell-slash",
          label: i18n("topics.bulk.dismiss_and_stop_tracking"),
          action: () => dismissNew(true),
        });
      }
    }

    if (this.args.showBulkSelect) {
      options.push({
        id: "bulk-select",
        icon: "list",
        label: i18n("topics.bulk.select"),
        pressed: this.args.bulkSelectHelper.bulkSelectEnabled,
        action: this.args.bulkSelectHelper.toggleBulkSelect,
      });
    }

    if (this.args.canReorderCategories) {
      options.push({
        id: "reorder-categories",
        icon: "shuffle",
        label: i18n("categories.reorder.title"),
        action: () =>
          this.args.reorderCategories({
            enableFixedPositions: !this.siteSettings.fixed_category_positions,
          }),
      });
    }

    if (this.args.canChangeCategorySettings) {
      options.push({
        id: "page-layout",
        icon: "table-columns",
        label: i18n("categories.page_layout"),
        href: getURL(PAGE_LAYOUT_SETTINGS_URL),
      });
    }

    return options;
  }

  @action
  async run(option, menu) {
    await menu.close();
    option.action();
  }

  <template>
    {{#let this.options as |options|}}
      {{#if (eq options.length 1)}}
        {{#let (get options "0") as |option|}}
          <DButton
            class="btn-transparent navigation-options__trigger navigation-options__{{option.id}}"
            @action={{option.action}}
            @ariaPressed={{option.pressed}}
            @href={{option.href}}
            @icon={{option.icon}}
            @translatedAriaLabel={{option.label}}
            @translatedTitle={{or option.title option.label}}
          />
        {{/let}}
      {{else if options.length}}
        <DMenu
          @ariaLabel={{i18n "topics.list_options"}}
          @icon="ellipsis-vertical"
          @identifier="navigation-options"
          @modalForMobile={{true}}
          @triggerClass="btn-transparent navigation-options__trigger"
        >
          <:content as |menu|>
            <DDropdownMenu as |dropdown|>
              {{#each options key="id" as |option|}}
                <dropdown.item>
                  <DButton
                    class="btn-transparent navigation-options__{{option.id}}"
                    @action={{if option.action (fn this.run option menu)}}
                    @ariaPressed={{option.pressed}}
                    @href={{option.href}}
                    @icon={{option.icon}}
                    @translatedLabel={{option.label}}
                    @translatedTitle={{option.title}}
                  />
                </dropdown.item>
              {{/each}}
            </DDropdownMenu>
          </:content>
        </DMenu>
      {{/if}}
    {{/let}}
  </template>
}
