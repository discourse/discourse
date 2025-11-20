import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { isArray } from "@ember/array";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import Tree from "discourse/admin/components/schema-setting/editor/tree";
import FieldInput from "discourse/admin/components/schema-setting/field";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cloneJSON } from "discourse/lib/object";
import { trackedArray } from "discourse/lib/tracked-tools";
import { gt, not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class SchemaSettingNewEditor extends Component {
  @service router;
  @service dialog;

  @tracked activeIndex = 0;
  @tracked saveButtonDisabled = false;
  @tracked validationErrorMessage;
  @trackedArray activeDataPaths = [];
  @trackedArray activeSchemaPaths = [];
  @trackedArray history = [];

  inputFieldObserver = new Map();
  data = this.#trackNestedArrays(cloneJSON(this.args.setting.value));
  schema = this.args.schema;

  @action
  onChildClick(index, propertyName, parentNodeIndex) {
    this.history.push({
      dataPaths: [...this.activeDataPaths],
      schemaPaths: [...this.activeSchemaPaths],
      index: this.activeIndex,
    });

    this.activeIndex = index;
    this.activeDataPaths.push(parentNodeIndex, propertyName);
    this.activeSchemaPaths.push(propertyName);
    this.inputFieldObserver.clear();
  }

  @action
  updateIndex(index) {
    this.activeIndex = index;
  }

  @action
  generateSchemaTitle(object, schema, index) {
    let title;

    if (schema.properties[schema.identifier]?.type === "categories") {
      title = this.activeData[index][schema.identifier]
        ?.map((categoryId) => {
          return this.args.setting.metadata.categories[categoryId].name;
        })
        .join(", ");
    } else {
      title = object[schema.identifier];
    }

    return title || `${schema.name} ${index + 1}`;
  }

  get backButtonText() {
    if (this.history.length === 0) {
      return;
    }

    const lastHistory = this.history.at(-1);

    return i18n("admin.customize.schema.back_button", {
      name: this.generateSchemaTitle(
        this.#resolveDataFromPaths(lastHistory.dataPaths)[lastHistory.index],
        this.#resolveSchemaFromPaths(lastHistory.schemaPaths),
        lastHistory.index
      ),
    });
  }

  get activeData() {
    return this.#resolveDataFromPaths(this.activeDataPaths);
  }

  #resolveDataFromPaths(paths) {
    if (paths.length === 0) {
      return this.data;
    }

    let data = this.data;

    paths.forEach((path) => {
      data = data[path];
    });

    return data;
  }

  get activeSchema() {
    return this.#resolveSchemaFromPaths(this.activeSchemaPaths);
  }

  #resolveSchemaFromPaths(paths) {
    if (paths.length === 0) {
      return this.schema;
    }

    let schema = this.schema;

    paths.forEach((path) => {
      schema = schema.properties[path].schema;
    });

    return schema;
  }

  @action
  registerInputFieldObserver(index, callback) {
    this.inputFieldObserver[index] = callback;
  }

  descriptions(fieldName, key) {
    // The `property_descriptions` metadata is an object with keys in the following format as an example:
    //
    // {
    //   some_property.description: <some description>,
    //   some_property.label: <some label>,
    //   some_objects_property.some_other_property.description: <some description>,
    //   some_objects_property.some_other_property.label: <some label>,
    // }
    const descriptions = this.args.setting.metadata?.property_descriptions;

    if (!descriptions) {
      return;
    }

    if (this.activeSchemaPaths.length > 0) {
      key = `${this.activeSchemaPaths.join(".")}.${fieldName}.${key}`;
    } else {
      key = `${fieldName}.${key}`;
    }

    return descriptions[key];
  }

  fieldLabel(fieldName, spec) {
    return this.descriptions(fieldName, "label") || spec?.label || fieldName;
  }

  fieldDescription(fieldName, spec) {
    return this.descriptions(fieldName, "description") || spec?.description;
  }

  get fields() {
    const list = [];
    const activeObject = this.activeData[this.activeIndex];

    if (activeObject) {
      for (const [name, spec] of Object.entries(this.activeSchema.properties)) {
        if (spec.type === "objects") {
          continue;
        }

        list.push({
          name,
          spec,
          value: activeObject[name],
          description: this.fieldDescription(name, spec),
          label: this.fieldLabel(name, spec),
        });
      }
    }

    return list;
  }

  @action
  clickBack() {
    const {
      dataPaths: lastDataPaths,
      schemaPaths: lastSchemaPaths,
      index: lastIndex,
    } = this.history.pop();

    this.activeDataPaths = lastDataPaths;
    this.activeSchemaPaths = lastSchemaPaths;
    this.activeIndex = lastIndex;
    this.inputFieldObserver.clear();
  }

  @action
  addChildItem(propertyName, parentNodeIndex) {
    this.activeData[parentNodeIndex][propertyName].push({});

    this.onChildClick(
      this.activeData[parentNodeIndex][propertyName].length - 1,
      propertyName,
      parentNodeIndex
    );
  }

  @action
  addItem() {
    this.activeData.push({});
    this.activeIndex = this.activeData.length - 1;
  }

  @action
  async removeItem() {
    let confirm = true;

    if (this.args.schema.deleteWarning) {
      confirm = await this._confirmRemove(this.args.schema.deleteWarning);
    }

    if (!confirm) {
      return;
    }

    this.activeData.splice(this.activeIndex, 1);

    if (this.activeData.length > 0) {
      this.activeIndex = Math.max(this.activeIndex - 1, 0);
    } else if (this.history.length > 0) {
      this.clickBack();
    } else {
      this.activeIndex = 0;
    }
  }

  @action
  inputFieldChanged(field, newVal) {
    this.activeData[this.activeIndex][field.name] = newVal;

    if (field.name === this.activeSchema.identifier) {
      this.inputFieldObserver[this.activeIndex]();
    }
  }

  @action
  moveUp() {
    if (this.canMoveUp) {
      this.#swapAdjacentItems(this.activeIndex, this.activeIndex - 1);
      this.activeIndex = this.activeIndex - 1;
    }
  }

  @action
  moveDown() {
    if (this.canMoveDown) {
      this.#swapAdjacentItems(this.activeIndex, this.activeIndex + 1);
      this.activeIndex = this.activeIndex + 1;
    }
  }

  #swapAdjacentItems(fromIndex, toIndex) {
    const item = this.activeData[fromIndex];
    const fromCallback = this.inputFieldObserver[fromIndex];
    const toCallback = this.inputFieldObserver[toIndex];

    // Move the data
    this.activeData.splice(fromIndex, 1);
    this.activeData.splice(toIndex, 0, item);

    // Swap the observer callbacks to match new positions
    this.inputFieldObserver[toIndex] = fromCallback;
    this.inputFieldObserver[fromIndex] = toCallback;
  }

  get canMoveUp() {
    return this.activeIndex > 0;
  }

  get canMoveDown() {
    return this.activeIndex < this.activeData.length - 1;
  }

  @action
  saveChanges() {
    this.saveButtonDisabled = true;
    this.args.setting
      .updateSetting(this.args.id, this.data)
      .then((result) => {
        this.args.setting.set("value", result[this.args.setting.setting]);
        this.router.transitionTo(this.args.routeToRedirect, this.args.id);
      })
      .catch((e) => {
        if (e.jqXHR.responseJSON && e.jqXHR.responseJSON.errors) {
          this.validationErrorMessage = e.jqXHR.responseJSON.errors[0];
        } else {
          popupAjaxError(e);
        }
      })
      .finally(() => (this.saveButtonDisabled = false));
  }

  async _confirmRemove(warning) {
    return new Promise((resolve) => {
      this.dialog.deleteConfirm({
        title: warning?.title,
        message: warning?.message,
        didCancel: () => resolve(false),
        didConfirm: () => resolve(true),
      });
    });
  }

  /**
   * Recursively converts nested arrays to TrackedArrays for reactivity
   *
   * @param {*} input - The input value to convert
   * @returns {TrackedArray|*} The converted value with TrackedArrays
   *
   * @private
   */
  #trackNestedArrays(input) {
    // Return early if input is null/undefined/empty
    if (!input) {
      return input;
    }

    // If input is an array, convert it to a TrackedArray and recursively convert its items
    if (isArray(input)) {
      return new TrackedArray(
        input.map((item) => this.#trackNestedArrays(item))
      );
    }

    // If input is an object, recursively convert its values
    if (typeof input === "object") {
      Object.keys(input).forEach((key) => {
        input[key] = this.#trackNestedArrays(input[key]);
      });
    }

    // Return the input after converting any arrays to TrackedArrays
    return input;
  }

  <template>
    <div class="schema-setting-editor">
      {{#if this.validationErrorMessage}}
        <div class="schema-setting-editor__errors">
          <div class="alert alert-error">
            {{this.validationErrorMessage}}
          </div>
        </div>
      {{/if}}

      <div class="schema-setting-editor__wrapper">
        <div class="schema-setting-editor__navigation">
          <Tree
            @data={{this.activeData}}
            @schema={{this.activeSchema}}
            @onChildClick={{this.onChildClick}}
            @clickBack={{this.clickBack}}
            @backButtonText={{this.backButtonText}}
            @activeIndex={{this.activeIndex}}
            @updateIndex={{this.updateIndex}}
            @addItem={{this.addItem}}
            @addChildItem={{this.addChildItem}}
            @generateSchemaTitle={{this.generateSchemaTitle}}
            @registerInputFieldObserver={{this.registerInputFieldObserver}}
          />

          <div class="schema-setting-editor__footer">
            <DButton
              @disabled={{this.saveButtonDisabled}}
              @action={{this.saveChanges}}
              @label="save"
              class="btn-primary"
            />
          </div>
        </div>

        <div class="schema-setting-editor__fields">
          {{#each this.fields as |field|}}
            <FieldInput
              @name={{field.name}}
              @value={{field.value}}
              @spec={{field.spec}}
              @onValueChange={{fn this.inputFieldChanged field}}
              @description={{field.description}}
              @label={{field.label}}
              @setting={{@setting}}
            />
          {{/each}}

          <div class="schema-setting-editor__field-actions">
            <DButton
              @action={{this.moveUp}}
              @icon="chevron-up"
              @disabled={{not this.canMoveUp}}
              @ariaLabel={{i18n "admin.customize.schema.move_up"}}
              class="btn-default schema-setting-editor__move-up-btn"
            />
            <DButton
              @action={{this.moveDown}}
              @icon="chevron-down"
              @disabled={{not this.canMoveDown}}
              @ariaLabel={{i18n "admin.customize.schema.move_down"}}
              class="btn-default schema-setting-editor__move-down-btn"
            />

            {{#if (gt this.fields.length 0)}}
              <DButton
                @action={{this.removeItem}}
                @icon="trash-can"
                class="btn-danger schema-setting-editor__remove-btn"
              />
            {{/if}}
          </div>
        </div>
      </div>
    </div>
  </template>
}
