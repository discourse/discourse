import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import directoryColumnIsAutomatic from "discourse/helpers/directory-column-is-automatic";
import directoryColumnIsUserField from "discourse/helpers/directory-column-is-user-field";
import directoryTableHeaderTitle from "discourse/helpers/directory-table-header-title";
import { reload } from "discourse/helpers/page-reloader";
import { ajax } from "discourse/lib/ajax";
import { extractError, popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DReorderableList from "discourse/ui-kit/d-reorderable-list";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";
import { i18n } from "discourse-i18n";

/**
 * The reordering surface behind `enable_new_reordering_controls`. Mirrors
 * `modal/edit-user-directory-columns.gjs`, over the shared reorderable list.
 *
 * TODO (ui-kit-reorderable-list-cleanup) rename this over `modal/edit-user-directory-columns.gjs`
 * and drop the branch in app/controllers/users.js.
 */
export default class EditUserDirectoryColumns extends Component {
  @tracked loading = true;
  @tracked columns;
  @tracked flash;

  /**
   * A plain-text name for a column, for the reorder controls and
   * announcements — the rendered header title can carry icon markup, which an
   * accessible name cannot.
   *
   * @param {Object} column - The column to name.
   * @returns {string} The translated column name.
   */
  columnLabel = (column) => {
    if (column.type === "automatic") {
      return i18n(`directory.${column.name}_long`, {
        defaultValue: i18n(`directory.${column.name}`),
      });
    }
    if (column.user_field) {
      return column.user_field.name;
    }
    return i18n(column.name);
  };

  constructor() {
    super(...arguments);
    this.setupColumns();
  }

  @action
  async setupColumns() {
    try {
      const response = await ajax("edit-directory-columns.json");
      this.loading = false;
      this.columns = response.directory_columns
        .sort((a, b) => (a.position > b.position ? 1 : -1))
        .map((c) => ({ ...c, enabled: Boolean(c.enabled) }));
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async save() {
    this.loading = true;
    this.flash = null;
    const data = {
      directory_columns: this.columns.map((c) => ({
        id: c.id,
        enabled: c.enabled,
        position: c.position,
      })),
    };

    try {
      await ajax("edit-directory-columns.json", { type: "PUT", data });
      reload();
    } catch (e) {
      this.loading = false;
      this.flash = extractError(e);
    }
  }

  @action
  resetToDefault() {
    const resetColumns = this.columns
      .sort((a, b) => {
        const a1 = a.automatic_position || (a.user_field?.position || 0) + 1000;
        const b1 = b.automatic_position || (b.user_field?.position || 0) + 1000;

        if (a1 === b1) {
          return a.name.localeCompare(b.name);
        } else {
          return a1 > b1 ? 1 : -1;
        }
      })
      .map((column, index) => ({
        ...column,
        position: column.automatic_position || index + 1,
        enabled: column.type === "automatic",
      }));

    this.columns = resetColumns;
  }

  /**
   * Applies a committed move and renumbers every column from its new visible
   * slot — the stored order is exactly the displayed one here.
   *
   * @param {Object} move - The normalized move from the list.
   */
  @action
  handleMove(move) {
    this.columns = move.proposedToItems.map((column, index) => ({
      ...column,
      position: index + 1,
    }));
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "directory.edit_columns.title"}}
      class="edit-user-directory-columns-modal"
      @flash={{this.flash}}
    >
      <:body>
        {{#if this.loading}}
          {{dLoadingSpinner size="large"}}
        {{else}}
          <DReorderableList
            @items={{this.columns}}
            @key="id"
            @label={{this.columnLabel}}
            @onMove={{this.handleMove}}
            @tag="div"
            @itemTag="div"
            @rowClass="edit-directory-column"
            class="edit-directory-columns-container"
          >
            <:row as |column|>
              <div class="left-content">
                <label class="column-name">
                  <Input @type="checkbox" @checked={{column.enabled}} />
                  {{#if (directoryColumnIsAutomatic column=column)}}
                    {{directoryTableHeaderTitle
                      field=column.name
                      icon=column.icon
                    }}
                  {{else if (directoryColumnIsUserField column=column)}}
                    {{directoryTableHeaderTitle
                      field=column.user_field.name
                      translated=true
                    }}
                  {{else}}
                    {{directoryTableHeaderTitle
                      field=(i18n column.name)
                      translated=true
                    }}
                  {{/if}}
                </label>
              </div>
            </:row>
          </DReorderableList>
        {{/if}}
      </:body>
      <:footer>
        <DButton
          @label="directory.edit_columns.save"
          @action={{this.save}}
          class="btn-primary"
        />
        <DButton
          @label="directory.edit_columns.reset_to_default"
          @action={{this.resetToDefault}}
          class="btn-default reset-to-default"
        />
      </:footer>
    </DModal>
  </template>
}
