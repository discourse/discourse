import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { modifier } from "ember-modifier";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import Form from "discourse/components/form";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import { loadNodeTypes } from "../../../lib/workflows/node-types";
import { getConfigurationSchema } from "../../../lib/workflows/property-engine";
import PropertyEngineConfigurator from "../configurators/property-engine";
import InputContext from "../context/input";
import OutputContext from "../context/output";

export default class NodeConfigurator extends Component {
  @tracked nodeName = this.args.model.node.name || "";
  @tracked isEditingName = false;
  @tracked nodeTypes = null;
  @tracked activeTab = "parameters";
  @tracked
  settingsFormData = {
    description: this.args.model.node.configuration?.description || "",
  };

  initialConfiguration = structuredClone(
    this.args.model.node.configuration || {}
  );
  parametersApi = null;

  focusNameInput = modifier((element) => {
    element.focus();
    element.select();
  });

  focusModal = modifier((element) => {
    requestAnimationFrame(() => {
      element.closest(".d-modal")?.querySelector(".btn")?.focus();
    });
  });

  constructor() {
    super(...arguments);
    this.#loadTypes();
  }

  get isLoading() {
    return this.nodeTypes === null;
  }

  async #loadTypes() {
    this.nodeTypes = await loadNodeTypes();
    this.#applySchemaDefaults();
  }

  #applySchemaDefaults() {
    const schema = this.configurationSchema;
    for (const [key, fieldSchema] of Object.entries(schema)) {
      if (this.initialConfiguration[key] === undefined) {
        if (fieldSchema.default !== undefined) {
          this.initialConfiguration[key] = fieldSchema.default;
        } else if (fieldSchema.type === "collection") {
          this.initialConfiguration[key] = [];
        }
      }
    }
  }

  get configurationSchema() {
    return getConfigurationSchema(
      this.nodeTypes,
      this.args.model.node.type,
      this.args.model.node.type_version
    );
  }

  get hasConfiguration() {
    return Object.keys(this.configurationSchema).length > 0;
  }

  @action
  switchTab(tab) {
    if (tab === "settings") {
      this.settingsFormData = {
        description: this.configuration.description || "",
      };
    }
    this.activeTab = tab;
  }

  @action
  registerParametersApi(api) {
    this.parametersApi = api;
  }

  @action
  handleDescriptionSet(value, { set, name }) {
    set(name, value);
    this.parametersApi?.set("description", value);
  }

  @action
  startEditingName() {
    this.isEditingName = true;
  }

  @action
  updateNodeName(event) {
    this.nodeName = event.target.value;
  }

  @action
  finishEditingName() {
    this.isEditingName = false;
  }

  @action
  handleNameKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      event.target.blur();
    }
  }

  get configuration() {
    if (!this.parametersApi) {
      return this.initialConfiguration;
    }

    const schema = this.configurationSchema;
    const config = {};
    for (const key of Object.keys(schema)) {
      const value = this.parametersApi.get(key);
      if (value !== undefined) {
        config[key] = value;
      }
    }

    // Include description from settings tab
    const description = this.parametersApi.get("description");
    if (description !== undefined) {
      config.description = description;
    }

    return config;
  }

  @action
  handleClose() {
    this.args.model.onSave(this.configuration, this.nodeName);
    this.args.closeModal();
  }

  <template>
    <DModal
      @closeModal={{this.handleClose}}
      @submitOnEnter={{false}}
      @hideHeader={{true}}
      class="workflows-configurator-modal"
    >
      <:body>
        <div class="workflows-configurator-modal__header" {{this.focusModal}}>
          {{#if this.isEditingName}}
            <input
              type="text"
              value={{this.nodeName}}
              class="workflows-configurator-modal__name-input"
              {{this.focusNameInput}}
              {{on "input" this.updateNodeName}}
              {{on "blur" this.finishEditingName}}
              {{on "keydown" this.handleNameKeydown}}
            />
          {{else}}
            {{! template-lint-disable no-invalid-interactive }}
            <div
              class="workflows-configurator-modal__name"
              {{on "click" this.startEditingName}}
            >{{this.nodeName}}</div>
          {{/if}}
          <DButton
            @action={{this.handleClose}}
            @icon="xmark"
            class="btn-flat workflows-configurator-modal__close"
          />
        </div>
        <ConditionalLoadingSpinner @condition={{this.isLoading}}>
          <div class="workflows-configurator-modal__columns">
            <div class="workflows-configurator-modal__column --left">
              <InputContext
                @node={{@model.node}}
                @nodes={{@model.nodes}}
                @connections={{@model.connections}}
                @triggerType={{@model.triggerType}}
                @nodeTypes={{this.nodeTypes}}
              />
            </div>

            <div class="workflows-configurator-modal__column --center">
              <div class="workflows-configurator__tabs">
                <button
                  type="button"
                  class="workflows-configurator__tab
                    {{if (eq this.activeTab 'parameters') '--active'}}"
                  {{on "click" (fn this.switchTab "parameters")}}
                >{{i18n
                    "discourse_workflows.configurator.tabs.parameters"
                  }}</button>
                <button
                  type="button"
                  class="workflows-configurator__tab
                    {{if (eq this.activeTab 'settings') '--active'}}"
                  {{on "click" (fn this.switchTab "settings")}}
                >{{i18n
                    "discourse_workflows.configurator.tabs.settings"
                  }}</button>
              </div>

              {{#if this.hasConfiguration}}
                <Form
                  @data={{this.initialConfiguration}}
                  @onRegisterApi={{this.registerParametersApi}}
                  @validateOn="change"
                  class="workflows-configurator-form
                    {{unless (eq this.activeTab 'parameters') '--hidden'}}"
                  as |form transientData|
                >
                  <PropertyEngineConfigurator
                    @form={{form}}
                    @formApi={{this.parametersApi}}
                    @configuration={{transientData}}
                    @nodeType={{@model.node.type}}
                    @schema={{this.configurationSchema}}
                    @triggerType={{@model.triggerType}}
                    @node={{@model.node}}
                    @nodes={{@model.nodes}}
                    @connections={{@model.connections}}
                    @nodeTypes={{this.nodeTypes}}
                  />
                </Form>
              {{else if (eq this.activeTab "parameters")}}
                <p>{{i18n
                    "discourse_workflows.configurator.no_configuration"
                  }}</p>
              {{/if}}

              {{#if (eq this.activeTab "settings")}}
                <Form
                  @data={{this.settingsFormData}}
                  class="workflows-configurator-form"
                  as |form|
                >
                  <form.Field
                    @name="description"
                    @title={{i18n
                      "discourse_workflows.configurator.description"
                    }}
                    @type="textarea"
                    @format="full"
                    @onSet={{this.handleDescriptionSet}}
                    as |field|
                  >
                    <field.Control
                      placeholder={{i18n
                        "discourse_workflows.configurator.description_placeholder"
                      }}
                    />
                  </form.Field>
                </Form>
              {{/if}}
            </div>

            <div class="workflows-configurator-modal__column --right">
              <OutputContext
                @node={{@model.node}}
                @nodes={{@model.nodes}}
                @connections={{@model.connections}}
                @triggerType={{@model.triggerType}}
                @nodeTypes={{this.nodeTypes}}
              />
            </div>
          </div>
        </ConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
