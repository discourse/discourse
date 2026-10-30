import Controller from "@ember/controller";
import { action, computed, get } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import EmailPreview from "discourse/admin/models/email-preview";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

const TEMPLATE_PREVIEW_PREFIX = "template:";

export default class AdminEmailPreviewDigestController extends Controller {
  @service dialog;
  @service siteSettings;

  /** @type {string | null | undefined} */
  username = null;

  /** @type {string | null} */
  lastSeen = null;

  /** @type {string} */
  emailType = "digest";

  /** @type {string | null} */
  locale = null;

  /** @type {string | null} */
  email = null;

  emailTemplates = [];
  messageTypes = [];
  brandingThemeOptions = [];
  themeId = "";
  renderedParameters = null;
  queryParams = [
    "username",
    { lastSeen: "last_seen_at" },
    { emailType: "email_type" },
    "locale",
    { themeId: "theme_id" },
  ];
  #refreshId = 0;

  get availableLocales() {
    return this.siteSettings.available_locales;
  }

  get emailTypes() {
    const messageTypes = this.messageTypes.map((type) => ({
      name: type.title,
      value: type.id,
    }));
    const selectedTemplate =
      this.isTemplatePreview &&
      this.emailTemplates.find(
        (template) =>
          `${TEMPLATE_PREVIEW_PREFIX}${template.id}` === this.emailType
      );
    if (selectedTemplate) {
      messageTypes.push({
        name: i18n("admin.email.preview_types.template", {
          name: selectedTemplate.title,
        }),
        value: this.emailType,
      });
    }
    return messageTypes;
  }

  get brandingThemes() {
    return [
      { name: i18n("admin.email.preview_default_theme"), value: "" },
      ...this.brandingThemeOptions.map((theme) => ({
        name: theme.title,
        value: theme.id,
      })),
    ];
  }

  @computed(
    "username",
    "lastSeen",
    "emailType",
    "locale",
    "themeId",
    "renderedParameters"
  )
  get previewStale() {
    return this.renderedParameters !== this.previewParameters;
  }

  get previewParameters() {
    return JSON.stringify([
      this.username,
      this.lastSeen,
      this.emailType,
      this.locale,
      this.themeId,
    ]);
  }

  @computed("emailType")
  get isDigest() {
    return this.emailType === "digest";
  }

  @computed("emailType")
  get isTemplatePreview() {
    return this.emailType.startsWith(TEMPLATE_PREVIEW_PREFIX);
  }

  @computed("email")
  get emailEmpty() {
    return isEmpty(this.email);
  }

  @computed("emailEmpty", "sendingEmail", "loading", "previewStale")
  get sendEmailDisabled() {
    return (
      this.emailEmpty || this.sendingEmail || this.loading || this.previewStale
    );
  }

  @computed("model.html_content")
  get showSendEmailForm() {
    return !isEmpty(this.model?.html_content);
  }

  @computed("model.html_content")
  get htmlEmpty() {
    return isEmpty(this.model?.html_content);
  }

  @action
  toggleShowHtml(event) {
    event?.preventDefault();
    this.toggleProperty("showHtml");
  }

  @action
  updateEmailType(emailType) {
    this.set("emailType", emailType);
  }

  @action
  updateLocale(locale) {
    this.set("locale", locale);
  }

  @action
  updateUsername(selected) {
    this.set("username", get(selected, "firstObject"));
  }

  @action
  updateTheme(themeId) {
    this.set("themeId", themeId);
  }

  cancelRefresh() {
    ++this.#refreshId;
    this.set("loading", false);
  }

  @action
  async refresh() {
    const requestId = ++this.#refreshId;
    this.set("loading", true);
    this.set("sentEmail", false);
    if (!this.username) {
      this.set("username", this.currentUser.username);
    }
    const parameters = this.previewParameters;
    try {
      const email = await EmailPreview.findPreview(
        this.username,
        this.lastSeen,
        this.emailType,
        this.locale,
        this.themeId
      );
      if (requestId === this.#refreshId) {
        this.model.setProperties(
          email.getProperties("subject", "html_content", "text_content")
        );
        this.set("renderedParameters", parameters);
      }
    } catch (error) {
      if (requestId === this.#refreshId) {
        this.set("renderedParameters", null);
        popupAjaxError(error);
      }
    } finally {
      if (requestId === this.#refreshId) {
        this.set("loading", false);
      }
    }
  }

  @action
  sendEmail() {
    if (this.sendEmailDisabled) {
      return;
    }
    this.set("sendingEmail", true);
    this.set("sentEmail", false);

    const parameters = this.previewParameters;
    EmailPreview.sendPreview(
      this.username,
      this.lastSeen,
      this.email,
      this.emailType,
      this.locale,
      this.themeId
    )
      .then((result) => {
        if (result.errors) {
          this.dialog.alert(result.errors);
        } else if (parameters === this.previewParameters) {
          this.set("sentEmail", true);
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.set("sendingEmail", false);
      });
  }
}
