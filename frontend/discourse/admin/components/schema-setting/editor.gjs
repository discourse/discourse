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
import { not } from "discourse/truth-helpers";
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
    if (!this.activeObject) {
      return [];
    }

    return Object.entries(this.activeSchema.properties)
      .filter(([, spec]) => spec.type !== "objects")
      .map(([name, spec]) => ({
        name,
        spec,
        description:
          this.#propertyMetadata(name, "description") || spec.description,
        label: this.#propertyMetadata(name, "label") || spec.label || name,
      }));
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
    let title = object[schema.identifier];

    if (schema.properties[schema.identifier]?.type === "categories") {
      title = title
        ?.map(
          (categoryId) =>
            this.args.setting.metadata?.categories?.[categoryId]?.name ||
            Category.findById(categoryId)?.name
        )
        .filter(Boolean)
        .join(", ");
    }

    return title || `${schema.name} ${index + 1}`;
  }

  @action
  clickBack() {
    const { dataPaths, schemaPaths, index } = this.history.pop();

    this.activeDataPaths = dataPaths;
    this.activeSchemaPaths = schemaPaths;
    this.activeIndex = index;
  }

  @action
  addChildItem(propertyName, parentNodeIndex) {
    const children = this.activeData[parentNodeIndex][propertyName];

    children.push(
      this.#prepareObject({}, this.activeSchema.properties[propertyName].schema)
    );

    this.onChildClick(children.length - 1, propertyName, parentNodeIndex);
  }

  @action
  addItem() {
    this.activeData.push(this.#prepareObject({}, this.activeSchema));
    this.activeIndex = this.activeData.length - 1;
  }

  @action
  async removeItem() {
    const warning = this.args.schema.deleteWarning;
    const confirmed =
      !warning ||
      (await this.dialog.deleteConfirm({
        title: warning.title,
        message: warning.message,
      }));

    if (!confirmed) {
      return;
    }

    this.activeData.splice(this.activeIndex, 1);

    if (this.activeData.length === 0 && this.history.length > 0) {
      this.clickBack();
      return;
    }

    this.activeIndex = Math.max(this.activeIndex - 1, 0);
  }

  @action
  inputFieldChanged(field, newVal) {
    this.activeObject[field.name] = newVal;
  }

  @action
  moveUp() {
    if (this.canMoveUp) {
      this.#moveActiveItem(-1);
    }
  }

  @action
  moveDown() {
    if (this.canMoveDown) {
      this.#moveActiveItem(1);
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
        const errors = e.jqXHR?.responseJSON?.errors;

        if (errors) {
          this.validationErrorMessage = errors[0];
        } else {
          popupAjaxError(e);
        }
      })
      .finally(() => (this.saveButtonDisabled = false));
  }

  #resolveDataFromPaths(paths) {
    return paths.reduce((data, path) => data[path], this.data);
  }

  #resolveSchemaFromPaths(paths) {
    return paths.reduce(
      (schema, path) => schema.properties[path].schema,
      this.schema
    );
  }

  #moveActiveItem(offset) {
    const [item] = this.activeData.splice(this.activeIndex, 1);
    this.activeData.splice(this.activeIndex + offset, 0, item);
    this.activeIndex += offset;
  }

  #prepareObject(object, schema) {
    for (const [name, spec] of Object.entries(schema.properties)) {
      if (spec.type === "objects") {
        object[name] = trackedArray(
          (object[name] || []).map((child) =>
            this.#prepareObject(child, spec.schema)
          )
        );
      } else if (spec.required && spec.type === "boolean") {
        object[name] ??= false;
      } else if (spec.required && spec.type === "enum") {
        object[name] ??= spec.default;
      } else if (Array.isArray(object[name])) {
        object[name] = trackedArray(object[name]);
      }
    }

    return trackedObject(object);
  }

  #propertyMetadata(fieldName, key) {
    return this.args.setting.metadata?.property_descriptions?.[
      [...this.activeSchemaPaths, fieldName, key].join(".")
    ];
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

            {{#if this.fields.length}}
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
