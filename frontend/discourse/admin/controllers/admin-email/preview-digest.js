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

  get availableLocales() {
    return this.siteSettings.available_locales;
  }

  get emailTypes() {
    const messageTypes = [
      {
        name: i18n("admin.email.preview_types.digest"),
        value: "digest",
      },
      {
        name: i18n("admin.email.preview_types.password_reset"),
        value: "password_reset",
      },
      {
        name: i18n("admin.email.preview_types.password_reset_code"),
        value: "password_reset_code",
      },
      {
        name: i18n("admin.email.preview_types.email_login_code"),
        value: "email_login_code",
      },
      {
        name: i18n("admin.email.preview_types.signup"),
        value: "signup",
      },
      {
        name: i18n("admin.email.preview_types.activation_reminder"),
        value: "activation_reminder",
      },
      {
        name: i18n("admin.email.preview_types.email_login"),
        value: "email_login",
      },
      {
        name: i18n("admin.email.preview_types.admin_login"),
        value: "admin_login",
      },
      {
        name: i18n("admin.email.preview_types.account_created"),
        value: "account_created",
      },
      {
        name: i18n("admin.email.preview_types.confirm_new_email"),
        value: "confirm_new_email",
      },
      {
        name: i18n("admin.email.preview_types.test_email"),
        value: "test_email",
      },
    ];
    const templateTypes = this.emailTemplates.map((template) => ({
      name: i18n("admin.email.preview_types.template", {
        name: template.title,
      }),
      value: `${TEMPLATE_PREVIEW_PREFIX}${template.id}`,
    }));

    return [...messageTypes, ...templateTypes];
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

  @computed("emailEmpty", "sendingEmail")
  get sendEmailDisabled() {
    return this.emailEmpty || this.sendingEmail;
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
  refresh() {
    const model = this.model;

    this.set("loading", true);
    this.set("sentEmail", false);

    let username = this.username;
    if (!username) {
      username = this.currentUser.get("username");
      this.set("username", username);
    }

    EmailPreview.findDigest(
      username,
      this.lastSeen,
      this.emailType,
      this.locale
    ).then((email) => {
      model.setProperties(
        email.getProperties("subject", "html_content", "text_content")
      );
      this.set("loading", false);
    });
  }

  @action
  sendEmail() {
    this.set("sendingEmail", true);
    this.set("sentEmail", false);

    EmailPreview.sendDigest(
      this.username,
      this.lastSeen,
      this.email,
      this.emailType,
      this.locale
    )
      .then((result) => {
        if (result.errors) {
          this.dialog.alert(result.errors);
        } else {
          this.set("sentEmail", true);
        }
      })
      .catch(popupAjaxError)
      .finally(() => {
        this.set("sendingEmail", false);
      });
  }
}
