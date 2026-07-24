import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { cancel, later } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import Form from "discourse/components/form";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { NODE_DIRECT_SETTING_KEYS } from "../../../lib/workflows/node-data-shape";
import {
  nodeTypeDescription,
  nodeTypeIcon,
  nodeTypeLabel,
  nodeTypeProducesData,
  nodeTypeRunScopeLabelKey,
  nodeTypeStyle,
  resolveNodeTypeVersion,
  typeVersionForNode,
} from "../../../lib/workflows/node-types";
import {
  credentialSlotAnchorField,
  credentialSlotVisible,
  credentialTypesForSlot,
  fieldType,
  findNodeType,
  getPropertySchema,
} from "../../../lib/workflows/property-engine";
import { runExecuteStep } from "../canvas/canvas-execute-step";
import { shouldShowExecuteStep } from "../canvas/workflow-node";
import CredentialControl from "../configurators/credential";
import PropertyEngineConfigurator from "../configurators/property-engine";
import InputContext from "../context/input";
import OutputContext from "../context/output";

function credentialSlotLabel(slot) {
  return i18n(slot.label_key || "discourse_workflows.credentials.type");
}

function normalizeCredentials(credentials = {}) {
  return Object.fromEntries(
    Object.entries(credentials || {}).filter(([, value]) => value?.id)
  );
}

function syncNameInputWidth(input) {
  input.style.setProperty(
    "--node-name-length",
    Math.max(input.value.length, 1) + 1
  );
}

const AUTOSAVE_DELAY_MS = 750;
const SAVED_FADE_DELAY_MS = 2500;
const SAVED_REMOVE_DELAY_MS = 3000;

export default class NodeConfigurator extends Component {
  @service router;
  @service toasts;
  @service workflowsNodeTypes;

  @tracked nodeName = this.args.model.node.name || "";
  @tracked isEditingName = false;
  @tracked nodeTypes = null;
  @tracked activeTab = "parameters";
  @tracked saveStatus = null;
  @tracked isSaveStatusFading = false;
  @tracked
  settingsFormData = {
    notes: this.args.model.node.configuration?.notes || "",
    notesInFlow: this.args.model.node.configuration?.notesInFlow === true,
    alwaysOutputData:
      this.args.model.node.configuration?.alwaysOutputData === true,
  };

  @tracked credentialConfig = structuredClone(
    normalizeCredentials(
      this.args.model.node.configuration?.credentials ||
        this.args.model.node.credentials
    )
  );
  initialConfiguration = structuredClone(
    this.args.model.node.configuration || {}
  );
  initialNodeName = this.args.model.node.name || "";
  nodeNameBeforeEditing = "";
  autosaveTimer = null;
  savedFadeTimer = null;
  savedRemoveTimer = null;

  parametersApi = null;
  settingsApi = null;

  focusNameInput = modifier((element) => {
    syncNameInputWidth(element);
    element.focus();
    element.select();
    const handler = () => syncNameInputWidth(element);
    element.addEventListener("input", handler);
    return () => element.removeEventListener("input", handler);
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

  willDestroy() {
    super.willDestroy(...arguments);
    this.#cancelTimers();
  }

  get isLoading() {
    return this.nodeTypes === null;
  }

  get resolvedNodeType() {
    return resolveNodeTypeVersion(
      findNodeType(this.nodeTypes, this.args.model.node.type),
      typeVersionForNode(this.args.model.node)
    );
  }

  async #loadTypes() {
    this.nodeTypes = await this.workflowsNodeTypes.load();
    this.#applyDefaults();
    this.#setSavedBaseline(this.configuration, this.initialNodeName);
  }

  #applyDefaults() {
    const config = this.initialConfiguration;

    for (const [key, fs] of Object.entries(this.propertySchema)) {
      if (config[key] != null) {
        continue;
      }
      if (fs.default !== undefined) {
        config[key] = fs.default;
      } else if (
        fieldType(fs) === "collection" ||
        fieldType(fs) === "fixed_collection"
      ) {
        config[key] = {};
      } else if (fieldType(fs) === "assignment_collection") {
        config[key] = { assignments: [] };
      } else if (fieldType(fs) === "array") {
        config[key] = [];
      }
    }
  }

  get nodeTypeDefaultName() {
    return nodeTypeLabel(this.resolvedNodeType);
  }

  get nodeDescription() {
    return nodeTypeDescription(this.resolvedNodeType);
  }

  get propertySchema() {
    return getPropertySchema(
      this.nodeTypes,
      this.args.model.node.type,
      typeVersionForNode(this.args.model.node)
    );
  }

  get showsOutputContext() {
    return nodeTypeProducesData(this.resolvedNodeType);
  }

  get hasConfiguration() {
    return (
      Object.keys(this.propertySchema).length > 0 ||
      this.credentialSlots.length > 0
    );
  }

  get credentialSlots() {
    return this.resolvedNodeType?.credentials || [];
  }

  get unanchoredCredentialSlots() {
    return this.credentialSlots.filter(
      (slot) => !credentialSlotAnchorField(slot)
    );
  }

  get isUnavailable() {
    const nodeType = this.resolvedNodeType;
    return nodeType?.available === false;
  }

  get unavailableReasonKey() {
    return this.resolvedNodeType?.unavailable_reason_key;
  }

  get trimmedNodeName() {
    return this.nodeName.trim();
  }

  get canSaveNodeName() {
    return this.trimmedNodeName.length > 0;
  }

  @action
  switchTab(tab) {
    if (tab === "settings") {
      this.settingsFormData = {
        notes: this.configuration.notes || "",
        notesInFlow: this.configuration.notesInFlow === true,
        alwaysOutputData: this.configuration.alwaysOutputData === true,
      };
    }
    this.activeTab = tab;
  }

  @action
  registerParametersApi(api) {
    this.parametersApi = api;
  }

  @action
  registerSettingsApi(api) {
    this.settingsApi = api;
  }

  @action
  async handleNotesSet(value, { set, name }) {
    const notes = value || "";
    await set(name, notes);
    await set("notesInFlow", notes.trim().length > 0);
  }

  @action
  async handleAlwaysOutputDataSet(value, { set, name }) {
    await set(name, value);
  }

  @action
  handleCredentialSet(slotName, value) {
    const credentials = { ...this.credentialConfig };
    if (value?.id) {
      credentials[slotName] = value;
    } else {
      delete credentials[slotName];
    }
    this.credentialConfig = credentials;
    this.scheduleSave();
  }

  @action
  credentialValue(slotName) {
    return this.credentialConfig[slotName];
  }

  @action
  startEditingName() {
    this.nodeNameBeforeEditing = this.nodeName;
    this.isEditingName = true;
  }

  @action
  updateNodeName(event) {
    this.nodeName = event.target.value;
  }

  @action
  async saveNodeName() {
    if (!this.canSaveNodeName) {
      return;
    }

    this.nodeName = this.trimmedNodeName;
    this.isEditingName = false;
    await this.saveCurrentConfiguration();
  }

  @action
  cancelEditingName() {
    this.nodeName = this.nodeNameBeforeEditing;
    this.isEditingName = false;
  }

  @action
  handleNameKeydown(event) {
    if (event.key === "Enter") {
      event.preventDefault();
      this.saveNodeName();
    } else if (event.key === "Escape") {
      this.cancelEditingName();
    }
  }

  get runScopeLabel() {
    const labelKey = nodeTypeRunScopeLabelKey(this.resolvedNodeType, {
      typeVersion: this.args.model.node.typeVersion,
      configuration: this.configuration,
    });
    return labelKey ? i18n(labelKey) : null;
  }

  get configuration() {
    if (!this.parametersApi) {
      return this.configurationWithDirectSettings(this.initialConfiguration);
    }

    const config = {};
    for (const key of [
      ...Object.keys(this.propertySchema),
      ...NODE_DIRECT_SETTING_KEYS,
    ]) {
      let value = this.parametersApi.get(key);
      if (
        value === undefined &&
        Object.hasOwn(this.initialConfiguration, key)
      ) {
        value = this.initialConfiguration[key];
      }
      if (value !== undefined) {
        config[key] = value;
      }
    }

    return this.configurationWithDirectSettings(config);
  }

  get settingsConfiguration() {
    if (!this.settingsApi) {
      return this.settingsFormData;
    }

    return {
      notes: this.settingsApi.get("notes") || "",
      notesInFlow: this.settingsApi.get("notesInFlow") === true,
      alwaysOutputData: this.settingsApi.get("alwaysOutputData") === true,
    };
  }

  configurationWithDirectSettings(config) {
    return {
      ...config,
      notes: this.settingsConfiguration.notes,
      notesInFlow: this.settingsConfiguration.notesInFlow,
      alwaysOutputData: this.settingsConfiguration.alwaysOutputData,
      credentials: this.credentialConfig,
    };
  }

  get isDirty() {
    const nameDirty = this.nodeName !== this.initialNodeName;
    const configurationDirty =
      JSON.stringify(this.configuration) !==
      JSON.stringify(this.initialConfiguration);
    return nameDirty || configurationDirty;
  }

  get showSaveStatus() {
    return this.saveStatus === "saving" || this.saveStatus === "saved";
  }

  #cancelTimers() {
    cancel(this.autosaveTimer);
    cancel(this.savedFadeTimer);
    cancel(this.savedRemoveTimer);
  }

  #cancelSavedTimers() {
    cancel(this.savedFadeTimer);
    cancel(this.savedRemoveTimer);
  }

  #setSavingStatus() {
    this.#cancelSavedTimers();
    this.isSaveStatusFading = false;
    this.saveStatus = "saving";
  }

  #setSavedStatus() {
    this.saveStatus = "saved";
    this.isSaveStatusFading = false;

    this.savedFadeTimer = later(() => {
      this.isSaveStatusFading = true;
    }, SAVED_FADE_DELAY_MS);

    this.savedRemoveTimer = later(() => {
      this.saveStatus = null;
      this.isSaveStatusFading = false;
    }, SAVED_REMOVE_DELAY_MS);
  }

  #setSavedBaseline(configuration, nodeName) {
    this.initialConfiguration = structuredClone(configuration);
    this.initialConfiguration.credentials = structuredClone(
      configuration.credentials
    );
    this.initialNodeName = nodeName;
  }

  async #saveConfiguration(options = {}) {
    if (!this.isDirty) {
      return;
    }

    const configuration = structuredClone(this.configuration);
    const nodeName = this.trimmedNodeName || this.initialNodeName;

    this.#setSavingStatus();
    await this.args.model.onSave(configuration, nodeName, options);
    this.#setSavedBaseline(configuration, nodeName);

    if (!this.isDirty) {
      this.#setSavedStatus();
    }
  }

  @action
  scheduleSave() {
    cancel(this.autosaveTimer);
    this.autosaveTimer = later(() => {
      this.#saveConfiguration({ throwOnError: true }).catch(() => {
        this.saveStatus = null;
        this.isSaveStatusFading = false;
      });
    }, AUTOSAVE_DELAY_MS);
  }

  @action
  async saveCurrentConfiguration() {
    cancel(this.autosaveTimer);
    await this.#saveConfiguration({ throwOnError: true });
  }

  @action
  handleClose() {
    if (this.isDirty) {
      cancel(this.autosaveTimer);
      this.args.model.onSave(
        this.configuration,
        this.trimmedNodeName || this.initialNodeName
      );
    }
    this.args.closeModal();
    this.args.model.session.clearEditingContext();
  }

  get canExecuteStep() {
    return shouldShowExecuteStep(this.args.model.node);
  }

  @action
  async executeStep() {
    try {
      await this.saveCurrentConfiguration();
      await runExecuteStep({
        clientId: this.args.model.node.clientId || this.args.model.node.id,
        workflowId: this.args.model.session?.workflowId,
        toasts: this.toasts,
        router: this.router,
      });
    } catch (e) {
      popupAjaxError(e);
    }
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
          {{#if (nodeTypeIcon this.resolvedNodeType)}}
            <span
              class="workflows-configurator-modal__node-icon"
              style={{nodeTypeStyle this.resolvedNodeType}}
            >
              {{dIcon (nodeTypeIcon this.resolvedNodeType)}}
            </span>
          {{/if}}
          {{#if this.isEditingName}}
            <input
              type="text"
              value={{this.nodeName}}
              class="workflows-configurator-modal__name-input"
              {{this.focusNameInput}}
              {{on "input" this.updateNodeName}}
              {{on "keydown" this.handleNameKeydown}}
            />
            <div class="workflows-configurator-modal__name-actions">
              <DButton
                @action={{this.saveNodeName}}
                @icon="check"
                @title="discourse_workflows.save"
                @disabled={{not this.canSaveNodeName}}
                class="btn-flat workflows-configurator-modal__save-name"
              />
              <DButton
                @action={{this.cancelEditingName}}
                @icon="xmark"
                @title="discourse_workflows.cancel"
                class="btn-flat workflows-configurator-modal__cancel-name"
              />
            </div>
          {{else}}
            {{! eslint-disable ember/template-no-invalid-interactive }}
            <div
              class="workflows-configurator-modal__name"
              {{on "click" this.startEditingName}}
            >{{this.nodeName}}</div>
            <DButton
              @action={{this.startEditingName}}
              @icon="pencil"
              @title="discourse_workflows.edit"
              class="btn-flat workflows-configurator-modal__edit-name"
            />
          {{/if}}
          {{#if this.showSaveStatus}}
            <span
              class={{dConcatClass
                "workflows-configurator-modal__save-status"
                (if
                  (eq this.saveStatus "saved")
                  "workflows-configurator-modal__save-status--saved"
                )
                (if
                  this.isSaveStatusFading
                  "workflows-configurator-modal__save-status--fading"
                )
              }}
            >
              {{#if (eq this.saveStatus "saving")}}
                <span
                  class="spinner workflows-configurator-modal__save-spinner"
                ></span>
                {{i18n "discourse_workflows.configurator.saving"}}
              {{else}}
                {{dIcon "check"}}
                {{i18n "discourse_workflows.configurator.saved"}}
              {{/if}}
            </span>
          {{/if}}
          {{#if this.canExecuteStep}}
            <DButton
              @action={{this.executeStep}}
              @icon="play"
              @label="discourse_workflows.execute_step.run"
              class="btn-small workflows-configurator-modal__execute-step"
            />
          {{/if}}
          <DButton
            @action={{this.handleClose}}
            @icon="xmark"
            class="btn-flat workflows-configurator-modal__close"
          />
        </div>
        <DConditionalLoadingSpinner @condition={{this.isLoading}}>
          {{#if this.isUnavailable}}
            <div class="workflows-configurator-modal__unavailable-banner">
              {{dIcon "triangle-exclamation"}}
              <span>{{i18n
                  (or
                    this.unavailableReasonKey
                    "discourse_workflows.node_unavailable.default"
                  )
                }}</span>
            </div>
          {{/if}}
          <div
            class={{dConcatClass
              "workflows-configurator-modal__columns"
              (if this.isUnavailable "is-unavailable")
            }}
          >
            <div class="workflows-configurator-modal__column --left">
              <InputContext
                @node={{@model.node}}
                @nodes={{@model.nodes}}
                @connections={{@model.connections}}
                @triggerType={{@model.triggerType}}
                @nodeTypes={{this.nodeTypes}}
                @session={{@model.session}}
                @hasConfiguration={{this.hasConfiguration}}
              />
            </div>

            <div class="workflows-configurator-modal__column --center">
              <div class="workflows-configurator__tabs">
                <button
                  type="button"
                  class={{dConcatClass
                    "workflows-configurator__tab"
                    (if (eq this.activeTab "parameters") "is-active")
                  }}
                  {{on "click" (fn this.switchTab "parameters")}}
                >{{i18n
                    "discourse_workflows.configurator.tabs.parameters"
                  }}</button>
                <button
                  type="button"
                  class={{dConcatClass
                    "workflows-configurator__tab"
                    (if (eq this.activeTab "settings") "is-active")
                  }}
                  {{on "click" (fn this.switchTab "settings")}}
                >{{i18n
                    "discourse_workflows.configurator.tabs.settings"
                  }}</button>
              </div>

              {{#if this.hasConfiguration}}
                <Form
                  @data={{this.initialConfiguration}}
                  @onRegisterApi={{this.registerParametersApi}}
                  @onSet={{this.scheduleSave}}
                  @validateOn="change"
                  class="workflows-configurator-form
                    {{unless (eq this.activeTab 'parameters') 'is-hidden'}}"
                  as |form transientData|
                >
                  <PropertyEngineConfigurator
                    @form={{form}}
                    @formApi={{this.parametersApi}}
                    @configuration={{transientData}}
                    @nodeType={{@model.node.type}}
                    @schema={{this.propertySchema}}
                    @credentials={{this.credentialConfig}}
                    @credentialSlots={{this.credentialSlots}}
                    @credentialValue={{this.credentialValue}}
                    @onCredentialSet={{this.handleCredentialSet}}
                    @triggerType={{@model.triggerType}}
                    @node={{@model.node}}
                    @nodeParameters={{transientData}}
                    @nodes={{@model.nodes}}
                    @connections={{@model.connections}}
                    @nodeTypes={{this.nodeTypes}}
                    @session={{@model.session}}
                    @onChange={{this.scheduleSave}}
                    @onBeforeStartTestSession={{this.saveCurrentConfiguration}}
                  />
                  {{#each this.unanchoredCredentialSlots as |slot|}}
                    {{#if (credentialSlotVisible slot transientData)}}
                      <CredentialControl
                        @credentialTypes={{credentialTypesForSlot slot}}
                        @label={{credentialSlotLabel slot}}
                        @onChange={{fn this.handleCredentialSet slot.name}}
                        @value={{this.credentialValue slot.name}}
                      />
                    {{/if}}
                  {{/each}}
                </Form>
              {{else if (eq this.activeTab "parameters")}}
                <p>{{i18n
                    "discourse_workflows.configurator.no_configuration"
                  }}</p>
              {{/if}}

              {{#if (eq this.activeTab "settings")}}
                {{#if this.runScopeLabel}}
                  <div class="workflows-configurator-modal__run-scope">
                    {{dIcon "circle-info"}}
                    <span>{{this.runScopeLabel}}</span>
                  </div>
                {{/if}}
                <Form
                  @data={{this.settingsFormData}}
                  @onRegisterApi={{this.registerSettingsApi}}
                  @onSet={{this.scheduleSave}}
                  class="workflows-configurator-form"
                  as |form|
                >
                  <form.Field
                    @name="notes"
                    @title={{i18n
                      "discourse_workflows.configurator.description"
                    }}
                    @type="textarea"
                    @format="full"
                    @onSet={{this.handleNotesSet}}
                    as |field|
                  >
                    <field.Control
                      placeholder={{i18n
                        "discourse_workflows.configurator.description_placeholder"
                      }}
                    />
                  </form.Field>
                  <form.Field
                    @name="alwaysOutputData"
                    @title={{i18n
                      "discourse_workflows.configurator.always_output_data"
                    }}
                    @description={{i18n
                      "discourse_workflows.configurator.always_output_data_help"
                    }}
                    @type="toggle"
                    @format="full"
                    @onSet={{this.handleAlwaysOutputDataSet}}
                    class="workflows-configurator-form__setting-toggle"
                    as |field|
                  >
                    <field.Control />
                  </form.Field>
                </Form>
                {{#if this.nodeDescription}}
                  <div class="workflows-configurator-modal__node">
                    <span class="workflows-configurator-modal__node-title">
                      {{#if (nodeTypeIcon this.resolvedNodeType)}}
                        <span
                          class="workflows-configurator-modal__node-icon"
                          style={{nodeTypeStyle this.resolvedNodeType}}
                        >
                          {{dIcon (nodeTypeIcon this.resolvedNodeType)}}
                        </span>
                      {{/if}}{{this.nodeTypeDefaultName}}
                    </span>
                    <p class="workflows-configurator-modal__node-description">
                      {{this.nodeDescription}}
                    </p>
                    <span class="workflows-configurator-modal__node-version">
                      v{{@model.node.typeVersion}}
                    </span>
                  </div>
                {{/if}}
              {{/if}}
            </div>

            {{#if this.showsOutputContext}}
              <div class="workflows-configurator-modal__column --right">
                <OutputContext
                  @node={{@model.node}}
                  @nodes={{@model.nodes}}
                  @connections={{@model.connections}}
                  @triggerType={{@model.triggerType}}
                  @nodeTypes={{this.nodeTypes}}
                  @session={{@model.session}}
                  @configuration={{this.configuration}}
                />
              </div>
            {{/if}}
          </div>
        </DConditionalLoadingSpinner>
      </:body>
    </DModal>
  </template>
}
