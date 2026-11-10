import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import type RouterService from "@ember/routing/router-service";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import type DialogService from "discourse/dialog-holder/services/dialog";
import DMenu from "discourse/float-kit/components/d-menu";
import type DMenuInstance from "discourse/float-kit/lib/d-menu-instance";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import { i18n } from "discourse-i18n";

const DESIGN_URL = "/admin/plugins/wireframe/companion.json";

/** A design as listed by the admin designs endpoint. */
export type AdminDesign = {
  /** The design component's theme ID. */
  id: number;
  /** Name the author gave the design. */
  name: string;
  /** ID of the theme the design belongs to. */
  theme_id: number;
  /** Name of the theme the design belongs to. */
  theme_name: string;
  /** Whether the design is the one the theme uses. */
  active: boolean;
  /** When the design last changed. */
  updated_at: string;
};

interface DesignsListSignature {
  /** The designs to list. */
  Args: {
    /** Every design across all themes. */
    designs: AdminDesign[];
  };
}

/**
 * The admin list of wireframe designs: each one's theme, whether the theme uses
 * it, and actions to switch to it or delete it.
 */
export default class DesignsList extends Component<DesignsListSignature> {
  /** Confirms deletion. */
  @service declare dialog: DialogService;

  /** Reloads the list after a change. */
  @service declare router: RouterService;

  /** Open row menus by design ID, so an action can close its menu. */
  #menus = new Map<number, DMenuInstance>();

  /**
   * Opens the editor on the homepage with a design selected, whether or not its
   * theme uses it. A full page load, so the page boots with the editor open on
   * that design.
   *
   * @param design - The design to edit.
   */
  @action
  edit(design: AdminDesign): void {
    this.#menus.get(design.id)?.close();
    window.location.assign(getURL(`/custom?wf_theme=${design.id}`));
  }

  @action
  registerMenu(designId: number, menu: DMenuInstance): void {
    this.#menus.set(designId, menu);
  }

  @action
  async useDesign(design: AdminDesign): Promise<void> {
    try {
      await ajax(DESIGN_URL, {
        type: "PUT",
        data: { theme_id: design.theme_id, design_id: design.id },
      });
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  confirmDelete(design: AdminDesign): void {
    this.#menus.get(design.id)?.close();
    this.dialog.deleteConfirm({
      title: i18n("wireframe.design.delete_confirm_title", {
        name: design.name,
      }),
      message: i18n("wireframe.design.delete_confirm_message"),
      didConfirm: () => this.#delete(design),
    });
  }

  async #delete(design: AdminDesign): Promise<void> {
    try {
      await ajax(DESIGN_URL, {
        type: "DELETE",
        data: { theme_id: design.theme_id, design_id: design.id },
      });
      this.router.refresh();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="wireframe-designs admin-detail">
      <DPageSubheader
        @descriptionLabel={{i18n "wireframe.admin.designs.description"}}
        @titleLabel={{i18n "wireframe.admin.designs.title"}}
      />

      {{#if @designs.length}}
        <table class="d-table wireframe-designs__table">
          <thead class="d-table__header">
            <tr class="d-table__row">
              <th class="d-table__header-cell">
                {{i18n "wireframe.admin.designs.name"}}
              </th>
              <th class="d-table__header-cell">
                {{i18n "wireframe.admin.designs.theme"}}
              </th>
              <th class="d-table__header-cell">
                {{i18n "wireframe.admin.designs.status"}}
              </th>
              <th class="d-table__header-cell">
                {{i18n "wireframe.admin.designs.updated"}}
              </th>
              <th class="d-table__header-cell"></th>
            </tr>
          </thead>
          <tbody class="d-table__body">
            {{#each @designs as |design|}}
              <tr
                class="d-table__row wireframe-designs__row"
                data-design-id={{design.id}}
              >
                <td class="d-table__cell --overview">
                  <span class="wireframe-designs__name">{{design.name}}</span>
                </td>
                <td class="d-table__cell --detail">
                  <div class="d-table__mobile-label">
                    {{i18n "wireframe.admin.designs.theme"}}
                  </div>
                  {{design.theme_name}}
                </td>
                <td class="d-table__cell --detail">
                  <div class="d-table__mobile-label">
                    {{i18n "wireframe.admin.designs.status"}}
                  </div>
                  {{#if design.active}}
                    <span class="wireframe-designs__status --active">
                      {{i18n "wireframe.admin.designs.in_use"}}
                    </span>
                  {{else}}
                    <span class="wireframe-designs__status">
                      {{i18n "wireframe.admin.designs.not_in_use"}}
                    </span>
                  {{/if}}
                </td>
                <td class="d-table__cell --detail">
                  <div class="d-table__mobile-label">
                    {{i18n "wireframe.admin.designs.updated"}}
                  </div>
                  {{dAgeWithTooltip design.updated_at}}
                </td>
                <td class="d-table__cell --controls">
                  <div class="d-table__cell-actions">
                    {{#unless design.active}}
                      <DButton
                        class="btn-default btn-small wireframe-designs__use"
                        @action={{fn this.useDesign design}}
                        @label="wireframe.admin.designs.use"
                      />
                    {{/unless}}
                    <DMenu
                      @icon="ellipsis-vertical"
                      @identifier="wireframe-design-menu"
                      @onRegisterApi={{fn this.registerMenu design.id}}
                      @title={{i18n "wireframe.admin.designs.more_options"}}
                      @triggerClass="btn-default btn-small wireframe-designs__menu"
                    >
                      <:content>
                        <DDropdownMenu as |dropdown|>
                          <dropdown.item>
                            <DButton
                              class="btn-transparent wireframe-designs__edit"
                              @action={{fn this.edit design}}
                              @icon="pencil"
                              @label="wireframe.admin.designs.edit"
                            />
                          </dropdown.item>
                          <dropdown.item>
                            <DButton
                              class="btn-transparent --danger wireframe-designs__delete"
                              @action={{fn this.confirmDelete design}}
                              @icon="trash-can"
                              @label="wireframe.design.delete"
                            />
                          </dropdown.item>
                        </DDropdownMenu>
                      </:content>
                    </DMenu>
                  </div>
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{else}}
        <AdminConfigAreaEmptyList @emptyLabel="wireframe.admin.designs.empty" />
      {{/if}}
    </div>
  </template>
}
