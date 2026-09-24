import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { action } from "@ember/object";
import { trackedArray, trackedObject } from "@ember/reactive/collections";
import { service } from "@ember/service";
import Tree from "discourse/admin/components/schema-setting/editor/tree";
import FieldInput from "discourse/admin/components/schema-setting/field";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cloneJSON } from "discourse/lib/object";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import Category from "discourse/models/category";
import { gt, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class SchemaSettingNewEditor extends Component {
  @service router;
  @service dialog;

  @tracked activeIndex = 0;
  @tracked saveButtonDisabled = false;
  @tracked validationErrorMessage;
  @autoTrackedArray activeDataPaths = [];
  @autoTrackedArray activeSchemaPaths = [];
  @autoTrackedArray history = [];

  schema = this.args.schema;
  data = trackedArray(
    cloneJSON(this.args.setting.value).map((object) =>
      this.#prepareObject(object, this.schema)
    )
  );

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

  get activeObject() {
    return this.activeData[this.activeIndex];
  }

  get activeSchema() {
    return this.#resolveSchemaFromPaths(this.activeSchemaPaths);
  }

  get fields() {
    const list = [];

    if (!this.activeObject) {
      return list;
    }

    for (const [name, spec] of Object.entries(this.activeSchema.properties)) {
      if (spec.type === "objects") {
        continue;
      }

      list.push({
        name,
        spec,
        description: this.fieldDescription(name, spec),
        label: this.fieldLabel(name, spec),
      });
    }

    return list;
  }

  get canMoveUp() {
    return this.activeIndex > 0;
  }

  get canMoveDown() {
    return this.activeIndex < this.activeData.length - 1;
  }

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
  }

  @action
  updateIndex(index) {
    this.activeIndex = index;
  }

  @action
  generateSchemaTitle(object, schema, index) {
    let title;

    if (schema.properties[schema.identifier]?.type === "categories") {
      title = object[schema.identifier]
        ?.map((categoryId) => {
          return (
            this.args.setting.metadata?.categories?.[categoryId]?.name ||
            Category.findById(categoryId)?.name
          );
        })
        .filter(Boolean)
        .join(", ");
    } else {
      title = object[schema.identifier];
    }

    return title || `${schema.name} ${index + 1}`;
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
  }

  @action
  addChildItem(propertyName, parentNodeIndex) {
    this.activeData[parentNodeIndex][propertyName].push(
      this.#prepareObject({}, this.activeSchema.properties[propertyName].schema)
    );

    this.onChildClick(
      this.activeData[parentNodeIndex][propertyName].length - 1,
      propertyName,
      parentNodeIndex
    );
  }

  @action
  addItem() {
    this.activeData.push(this.#prepareObject({}, this.activeSchema));
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
    this.activeObject[field.name] = newVal;
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

  @action
  saveChanges() {
    this.saveButtonDisabled = true;
    this.args.setting
      .updateSetting(this.args.id, this.data)
      .then((result) => {
        if (result) {
          this.args.setting.set("value", result[this.args.setting.setting]);
        }
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

  #swapAdjacentItems(fromIndex, toIndex) {
    const item = this.activeData[fromIndex];

    this.activeData.splice(fromIndex, 1);
    this.activeData.splice(toIndex, 0, item);
  }

  #prepareObject(object, schema) {
    for (const [name, spec] of Object.entries(schema.properties)) {
      if (spec.type === "objects") {
        object[name] = trackedArray(
          (object[name] || []).map((child) =>
            this.#prepareObject(child, spec.schema)
          )
        );
      } else if (Array.isArray(object[name])) {
        object[name] = trackedArray(object[name]);
      }
    }

    return trackedObject(object);
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
            @activeIndex={{this.activeIndex}}
            @addChildItem={{this.addChildItem}}
            @addItem={{this.addItem}}
            @backButtonText={{this.backButtonText}}
            @clickBack={{this.clickBack}}
            @data={{this.activeData}}
            @generateSchemaTitle={{this.generateSchemaTitle}}
            @onChildClick={{this.onChildClick}}
            @schema={{this.activeSchema}}
            @updateIndex={{this.updateIndex}}
          />

          <div class="schema-setting-editor__footer">
            <DButton
              class="btn-primary"
              @action={{this.saveChanges}}
              @disabled={{this.saveButtonDisabled}}
              @label="save"
            />
          </div>
        </div>

        <div class="schema-setting-editor__fields">
          {{#each this.fields as |field|}}
            <FieldInput
              @description={{field.description}}
              @label={{field.label}}
              @name={{field.name}}
              @onValueChange={{fn this.inputFieldChanged field}}
              @setting={{@setting}}
              @spec={{field.spec}}
              @value={{get this.activeObject field.name}}
            />
          {{/each}}

          <div class="schema-setting-editor__field-actions">
            <DButton
              class="btn-default schema-setting-editor__move-up-btn"
              @action={{this.moveUp}}
              @ariaLabel={{i18n "admin.customize.schema.move_up"}}
              @disabled={{not this.canMoveUp}}
              @icon="chevron-up"
            />
            <DButton
              class="btn-default schema-setting-editor__move-down-btn"
              @action={{this.moveDown}}
              @ariaLabel={{i18n "admin.customize.schema.move_down"}}
              @disabled={{not this.canMoveDown}}
              @icon="chevron-down"
            />

            {{#if (gt this.fields.length 0)}}
              <DButton
                class="btn-danger schema-setting-editor__remove-btn"
                @action={{this.removeItem}}
                @icon="trash-can"
              />
            {{/if}}
          </div>
        </div>
      </div>
    </div>
  </template>
}
