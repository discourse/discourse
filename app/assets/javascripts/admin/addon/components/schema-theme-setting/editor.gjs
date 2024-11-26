import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { gt } from "truth-helpers";
import DButton from "discourse/components/d-button";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { cloneJSON } from "discourse-common/lib/object";
import { i18n } from "discourse-i18n";
import Tree from "admin/components/schema-theme-setting/editor/tree";
import FieldInput from "admin/components/schema-theme-setting/field";

export default class SchemaThemeSettingNewEditor extends Component {
  @service router;

  @tracked history = [];
  @tracked activeIndex = 0;
  @tracked activeDataPaths = [];
  @tracked activeSchemaPaths = [];
  @tracked saveButtonDisabled = false;
  @tracked validationErrorMessage;
  inputFieldObserver = new Map();

  data = cloneJSON(this.args.setting.value);
  schema = this.args.setting.objects_schema;

  @action
  onChildClick(index, propertyName, parentNodeIndex) {
    this.history.pushObject({
      dataPaths: [...this.activeDataPaths],
      schemaPaths: [...this.activeSchemaPaths],
      index: this.activeIndex,
    });

    this.activeIndex = index;
    this.activeDataPaths.pushObjects([parentNodeIndex, propertyName]);
    this.activeSchemaPaths.pushObject(propertyName);
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

    const lastHistory = this.history[this.history.length - 1];

    return i18n("admin.customize.theme.schema.back_button", {
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

  @action
  unregisterInputFieldObserver(index) {
    delete this.inputFieldObserver[index];
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

  fieldLabel(fieldName) {
    return this.descriptions(fieldName, "label") || fieldName;
  }

  fieldDescription(fieldName) {
    return this.descriptions(fieldName, "description");
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
          description: this.fieldDescription(name),
          label: this.fieldLabel(name),
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
    } = this.history.popObject();

    this.activeDataPaths = lastDataPaths;
    this.activeSchemaPaths = lastSchemaPaths;
    this.activeIndex = lastIndex;
    this.inputFieldObserver.clear();
  }

  @action
  addChildItem(propertyName, parentNodeIndex) {
    this.activeData[parentNodeIndex][propertyName].pushObject({});

    this.onChildClick(
      this.activeData[parentNodeIndex][propertyName].length - 1,
      propertyName,
      parentNodeIndex
    );
  }

  @action
  addItem() {
    this.activeData.pushObject({});
    this.activeIndex = this.activeData.length - 1;
  }

  @action
  removeItem() {
    this.activeData.removeAt(this.activeIndex);

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
  saveChanges() {
    this.saveButtonDisabled = true;

    this.args.setting
      .updateSetting(this.args.themeId, this.data)
      .then((result) => {
        this.args.setting.set("value", result[this.args.setting.setting]);

        this.router.transitionTo(
          "adminCustomizeThemes.show",
          this.args.themeId
        );
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

  <template>
    <div class="schema-theme-setting-editor">
      {{#if this.validationErrorMessage}}
        <div class="schema-theme-setting-editor__errors">
          <div class="alert alert-error">
            {{this.validationErrorMessage}}
          </div>
        </div>
      {{/if}}

      <div class="schema-theme-setting-editor__wrapper">
        <div class="schema-theme-setting-editor__navigation">
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
            @unregisterInputFieldObserver={{this.unregisterInputFieldObserver}}
          />

          <div class="schema-theme-setting-editor__footer">
            <DButton
              @disabled={{this.saveButtonDisabled}}
              @action={{this.saveChanges}}
              @label="save"
              class="btn-primary"
            />
          </div>
        </div>

        <div class="schema-theme-setting-editor__fields">
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

          {{#if (gt this.fields.length 0)}}
            <DButton
              @action={{this.removeItem}}
              @icon="trash-can"
              class="btn-danger schema-theme-setting-editor__remove-btn"
            />
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
