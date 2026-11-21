import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { uniqueId } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { extractError, popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import DNativeSelect, {
  DNativeSelectOption,
  NO_VALUE_OPTION,
} from "discourse/ui-kit/d-native-select";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  ACCOUNT_ONLY,
  accountOnlyForm,
  canCreateRegistrationForm,
  fetchRegistrationForm,
  listRegistrationForms,
  openRegistrationFormEditor,
  registrationFormManagementUrl,
  registrationFormSelection,
  registrationFormsPath,
} from "../lib/registration-forms.js";
import EventRegistration from "./modal/event-registration.gjs";

const AdvancedRegistrationField = <template>
  <@form.Field
    @format="full"
    @helpText={{@notice}}
    @name="registrationForm"
    @onSet={{@onSelect}}
    @title={{i18n "event_registration.select"}}
    @type="select"
    as |field|
  >
    {{yield field.Control field.id to="select"}}
    {{yield to="preview"}}
    {{yield to="error"}}
  </@form.Field>
</template>;

const CompactRegistrationField = <template>
  <div class="event-registration-picker">
    {{dIcon "clipboard-list"}}
    <div class="event-registration-picker__controls">
      {{#let (uniqueId) as |id|}}
        <label class="sr-only" for={{id}}>{{i18n
            "event_registration.select"
          }}</label>
        <div
          class="event-registration-picker__selection
            {{unless @selectedTitle '--empty'}}"
        >
          <span
            aria-hidden="true"
            class="d-native-select event-registration-picker__sizer"
          >
            {{or @selectedTitle (i18n "event_registration.none")}}
          </span>
          {{yield
            (component DNativeSelect onChange=@onSelect value=@value)
            id
            to="select"
          }}
        </div>
      {{/let}}
      {{yield to="preview"}}
    </div>
    {{yield to="error"}}
    {{#if @notice}}
      <p class="event-registration-picker__notice"><small
        >{{@notice}}</small></p>
    {{/if}}
  </div>
</template>;

export default class EventRegistrationPicker extends Component {
  @service currentUser;
  @service dialog;
  @service modal;
  @service siteSettings;

  @tracked forms;
  @tracked error;

  #disconnectEditor;
  #listVersion = 0;
  #selectElement;

  willDestroy() {
    super.willDestroy(...arguments);
    this.#listVersion++;
    this.#disconnectEditor?.();
    window.removeEventListener("focus", this.refresh);
  }

  get canCreateForm() {
    return canCreateRegistrationForm(this.currentUser, this.siteSettings);
  }

  get #newFormUrl() {
    return getURL(
      this.currentUser.admin
        ? registrationFormsPath + "/new"
        : "/discourse-post-event/registration-forms/new"
    );
  }

  get value() {
    return registrationFormSelection(
      this.args.selectedId,
      this.args.definition
    );
  }

  get selectedTitle() {
    if (this.value === ACCOUNT_ONLY) {
      return i18n("event_registration.account_only");
    }
    if (this.unavailableSelection) {
      return (
        this.args.definition?.title ||
        i18n("event_registration.library.removed_form")
      );
    }
    return this.value === "legacy"
      ? this.args.originalDefinition?.title
      : this.forms?.find((form) => form.id === Number(this.value))?.title;
  }

  get unavailableSelection() {
    return (
      this.forms &&
      this.args.selectedId &&
      !this.forms.some((form) => form.id === Number(this.args.selectedId))
    );
  }

  @action
  start(element) {
    this.#selectElement = element;
    this.refresh();
    window.addEventListener("focus", this.refresh);
  }

  @action
  async refresh() {
    const version = ++this.#listVersion;
    let forms, error;
    try {
      forms = await listRegistrationForms();
    } catch (e) {
      error = extractError(e);
    }
    if (version === this.#listVersion) {
      this.error = error;
      if (forms) {
        this.forms = forms;
      }
    }
  }

  @action
  select(value) {
    this.#disconnectEditor?.();
    this.#disconnectEditor = null;
    if (value === ACCOUNT_ONLY) {
      this.args.onSelect(null, accountOnlyForm());
      return;
    }
    if (value === "create" || value === "manage") {
      this.#selectElement.value = this.value ?? NO_VALUE_OPTION;
      if (!this.canCreateForm) {
        return;
      }
      if (value === "create") {
        this.#openEditor();
      } else {
        this.#openManagement();
      }
      return;
    }
    const id = value && value !== "legacy" ? Number(value) : null;
    const definition =
      value === "legacy" || (id && id === this.args.originalId)
        ? this.args.originalDefinition
        : null;
    this.args.onSelect(id, definition);
  }

  @action
  async preview() {
    try {
      const definition =
        this.args.definition ??
        (await fetchRegistrationForm(this.args.selectedId)).definition;
      if (this.args.onPreview) {
        this.args.onPreview(definition);
      } else {
        this.modal.show(EventRegistration, { model: { definition } });
      }
    } catch (error) {
      popupAjaxError(error);
    }
  }

  #openManagement() {
    const tab = window.open(
      registrationFormManagementUrl(this.currentUser),
      "_blank"
    );
    if (tab) {
      tab.opener = null;
    } else {
      this.dialog.alert(i18n("event_registration.library.management_blocked"));
    }
  }

  #openEditor() {
    this.#disconnectEditor = openRegistrationFormEditor(
      this.#newFormUrl,
      (form) => {
        this.#disconnectEditor = null;
        // An older list response can arrive after the editor saves.
        this.#listVersion++;
        this.forms = [
          ...(this.forms || []).filter(({ id }) => id !== form.id),
          form,
        ];
        this.error = null;
        this.args.onSelect(form.id, null);
      }
    );
    if (!this.#disconnectEditor) {
      this.dialog.alert(i18n("event_registration.editor_blocked"));
    }
  }

  <template>
    {{#let
      (if @form AdvancedRegistrationField CompactRegistrationField)
      as |Layout|
    }}
      <Layout
        @form={{@form}}
        @notice={{if this.value (i18n "event_registration.host_notice")}}
        @onSelect={{this.select}}
        @selectedTitle={{this.selectedTitle}}
        @value={{this.value}}
      >
        <:select as |Control id|>
          <Control
            class="event-registration-picker__select"
            id={{id}}
            @includeNone={{true}}
            @nonePlaceholder={{i18n "event_registration.none"}}
            {{didInsert this.start}}
            as |select|
          >
            <select.Option @value={{ACCOUNT_ONLY}}>{{i18n
                "event_registration.account_only"
              }}</select.Option>
            {{#if
              (and
                @originalDefinition
                (not @originalId)
                (not (eq @originalDefinition.builtin ACCOUNT_ONLY))
              )
            }}
              <select.Option
                @value="legacy"
              >{{@originalDefinition.title}}</select.Option>
            {{/if}}
            {{#each this.forms as |item|}}
              <select.Option @value={{item.id}}>{{item.title}}</select.Option>
            {{/each}}
            {{#if this.unavailableSelection}}
              <DNativeSelectOption
                disabled
                @selected={{this.value}}
                @value={{@selectedId}}
              >{{this.selectedTitle}}</DNativeSelectOption>
            {{/if}}
            {{#if this.canCreateForm}}
              <hr />
              <select.Option @value="create">{{i18n
                  "event_registration.create"
                }}</select.Option>
              <select.Option @value="manage">{{i18n
                  (if
                    this.currentUser.staff
                    "event_registration.library.manage"
                    "event_registration.library.manage_mine"
                  )
                }}</select.Option>
            {{/if}}
          </Control>
        </:select>
        <:preview>
          {{#if (and this.value (not (eq this.value ACCOUNT_ONLY)))}}
            <DButton
              class="btn-link"
              @action={{this.preview}}
              @label="event_registration.preview"
            />
          {{/if}}
        </:preview>
        <:error>
          {{#if this.error}}
            <div role="alert">{{this.error}}
              <DButton
                class="btn-default"
                @action={{this.refresh}}
                @label="event_registration.retry"
              /></div>
          {{/if}}
        </:error>
      </Layout>
    {{/let}}
  </template>
}
