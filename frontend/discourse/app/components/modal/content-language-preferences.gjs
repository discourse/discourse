import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  AUTOMATICALLY_TRANSLATE_COOKIE,
  AUTOMATICALLY_TRANSLATE_COOKIE_EXPIRY,
  automaticallyTranslate,
  normalizeUnderstoodLanguages,
} from "discourse/lib/content-localization";
import cookie from "discourse/lib/cookie";
import getURL from "discourse/lib/get-url";
import MultiSelect from "discourse/select-kit/components/multi-select";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DModalCancel from "discourse/ui-kit/d-modal-cancel";
import I18n, { i18n } from "discourse-i18n";

export default class ContentLanguagePreferencesModal extends Component {
  @service currentUser;
  @service siteSettings;
  @service languageNameLookup;

  @tracked formApi;
  @tracked saving = false;

  @cached
  get data() {
    const interfaceLanguage = this.currentUser?.effective_locale ?? I18n.locale;

    return {
      interfaceLanguage,
      understoodLanguages: normalizeUnderstoodLanguages(
        this.currentUser?.user_option?.understood_languages
      ),
      automaticallyTranslate: automaticallyTranslate(this.currentUser),
    };
  }

  get interfaceLanguageOptions() {
    return this.siteSettings.available_locales.map(({ value }) => ({
      name: this.languageNameLookup.getLanguageName(value),
      value,
      id: value,
    }));
  }

  get canChangeInterfaceLanguage() {
    return (
      this.siteSettings.allow_user_locale &&
      (this.currentUser || this.siteSettings.set_locale_from_cookie)
    );
  }

  get interfaceLanguageReadOnly() {
    return !this.canChangeInterfaceLanguage;
  }

  get loginPath() {
    return getURL("/login");
  }

  @action
  registerFormApi(formApi) {
    this.formApi = formApi;
  }

  @action
  submit() {
    this.formApi.submit();
  }

  @action
  setInterfaceLanguage(value, { set }) {
    return set("interfaceLanguage", value);
  }

  @action
  setUnderstoodLanguages(value, { set }) {
    return set("understoodLanguages", normalizeUnderstoodLanguages(value));
  }

  @action
  async save(data) {
    this.saving = true;

    try {
      if (this.currentUser) {
        const understoodLanguages = normalizeUnderstoodLanguages(
          data.understoodLanguages
        );

        const preferences = {
          automatically_translate: data.automaticallyTranslate,
          understood_languages: understoodLanguages,
        };
        if (this.canChangeInterfaceLanguage) {
          preferences.locale = data.interfaceLanguage;
        }

        await ajax(`/u/${this.currentUser.username}.json`, {
          type: "PUT",
          contentType: "application/json",
          data: JSON.stringify(preferences),
        });
        if (this.canChangeInterfaceLanguage) {
          this.currentUser.set("locale", data.interfaceLanguage);
          this.currentUser.set("effective_locale", data.interfaceLanguage);
        }
        this.currentUser.set(
          "user_option.automatically_translate",
          data.automaticallyTranslate
        );
        this.currentUser.set(
          "user_option.understood_languages",
          understoodLanguages
        );
      } else {
        if (this.canChangeInterfaceLanguage) {
          cookie("locale", data.interfaceLanguage, { path: "/" });
        }
        cookie(AUTOMATICALLY_TRANSLATE_COOKIE, data.automaticallyTranslate, {
          path: "/",
          expires: AUTOMATICALLY_TRANSLATE_COOKIE_EXPIRY,
        });
      }

      this.args.closeModal();
      window.location.reload();
    } catch (error) {
      popupAjaxError(error);
      this.saving = false;
    }
  }

  <template>
    <DModal
      @title={{i18n "content_localization.preferences.title"}}
      @closeModal={{@closeModal}}
      class="content-language-preferences-modal"
    >
      <:body>
        <Form
          @data={{this.data}}
          @onSubmit={{this.save}}
          @onRegisterApi={{this.registerFormApi}}
          as |form|
        >
          <form.Field
            @name="interfaceLanguage"
            @type="select"
            @title={{i18n "user.locale.title"}}
            @validation="required"
            @format="full"
            @onSet={{this.setInterfaceLanguage}}
            @disabled={{this.interfaceLanguageReadOnly}}
            as |field|
          >
            <field.Control as |select|>
              {{#each this.interfaceLanguageOptions as |language|}}
                <select.Option @value={{language.value}}>
                  {{language.name}}
                </select.Option>
              {{/each}}
            </field.Control>
          </form.Field>

          {{#if this.currentUser}}
            <form.Field
              @name="understoodLanguages"
              @type="custom"
              @title={{i18n "user.content_languages.understood"}}
              @description={{i18n
                "user.content_languages.understood_description"
              }}
              @showOptional={{false}}
              @format="full"
              @onSet={{this.setUnderstoodLanguages}}
              as |field|
            >
              <field.Control>
                <MultiSelect
                  @valueProperty="value"
                  @langProperty="value"
                  @content={{this.interfaceLanguageOptions}}
                  @value={{field.value}}
                  @onChange={{field.set}}
                  @options={{hash filterable=true}}
                />
              </field.Control>
            </form.Field>
          {{else}}
            <div class="content-language-preferences-modal__understood">
              <span>{{i18n "user.content_languages.understood"}}</span>
              <a href={{this.loginPath}}>{{i18n
                  "content_localization.preferences.login_to_set_languages"
                }}</a>
            </div>
          {{/if}}

          <form.Field
            @name="automaticallyTranslate"
            @type="checkbox"
            @title={{i18n "user.automatically_translate"}}
            @format="full"
            as |field|
          >
            <field.Control data-test-automatically-translate />
          </form.Field>
        </Form>
      </:body>

      <:footer>
        <DButton
          @label="save"
          @action={{this.submit}}
          @disabled={{this.saving}}
          class="btn-primary"
        />
        <DModalCancel @close={{@closeModal}} />
      </:footer>
    </DModal>
  </template>
}
