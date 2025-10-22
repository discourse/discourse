import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import directoryColumnIsAutomatic from "discourse/helpers/directory-column-is-automatic";
import directoryColumnIsUserField from "discourse/helpers/directory-column-is-user-field";
import directoryTableHeaderTitle from "discourse/helpers/directory-table-header-title";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { reload } from "discourse/helpers/page-reloader";
import { ajax } from "discourse/lib/ajax";
import { extractError, popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const UP = "up";
const DOWN = "down";

export default class EditUserDirectoryColumns extends Component {
  @tracked loading = true;
  @tracked columns;
  @tracked labelKey;
  @tracked flash;

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

  @action
  moveUp(column) {
    this._moveColumn(UP, column);
  }

  @action
  moveDown(column) {
    this._moveColumn(DOWN, column);
  }

  _moveColumn(direction, column) {
    if (
      (direction === UP && column.position === 1) ||
      (direction === DOWN && column.position === this.columns.length)
    ) {
      return;
    }

    const positionOnClick = column.position;
    const newPosition =
      direction === UP ? positionOnClick - 1 : positionOnClick + 1;
    const previousColumn = this.columns.find((c) => c.position === newPosition);
    column.position = newPosition;
    previousColumn.position = positionOnClick;
    this.columns = this.columns.sort((a, b) =>
      a.position > b.position ? 1 : -1
    );
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
          {{loadingSpinner size="large"}}
        {{else}}
          <div class="edit-directory-columns-container">
            {{#each this.columns as |column|}}
              <div class="edit-directory-column">
                <div class="left-content">
                  <label class="column-name">
                    <Input @type="checkbox" @checked={{column.enabled}} />
                    {{#if (directoryColumnIsAutomatic column=column)}}
                      {{directoryTableHeaderTitle
                        field=column.name
                        labelKey=this.labelKey
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
                <div class="right-content">
                  <DButton
                    @icon="arrow-up"
                    @action={{fn this.moveUp column}}
                    class="button-secondary move-column-up"
                  />
                  <DButton
                    @icon="arrow-down"
                    @action={{fn this.moveDown column}}
                    class="button-secondary"
                  />
                </div>
              </div>
            {{/each}}
          </div>
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
          class="btn-secondary reset-to-default"
        />
      </:footer>
    </DModal>
  </template>
}
