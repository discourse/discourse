import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { isDevelopment } from "discourse/lib/environment";
import { currentThemeId } from "discourse/lib/theme-selector";
import { DeferredTrackedSet } from "discourse/lib/tracked-tools";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const _pluginNotices = new DeferredTrackedSet();

export function addGlobalNotice(text, id, options = {}) {
  _pluginNotices.add(Notice.create({ text, id, options }));
}

const GLOBAL_NOTICE_DISMISSED_PROMPT_KEY = "dismissed-global-notice-v2";

/**
 * @typedef {object} NoticeOptions
 * @property {boolean} [dismissable]
 * @property {string | null} [html]
 * @property {string} [level]
 * @property {boolean} [persistentDismiss]
 * @property {((notice: Notice) => void) | null} [onDismiss]
 * @property {((notice: Notice) => boolean) | null} [visibility]
 * @property {import("moment").Duration | null} [dismissDuration]
 */

class Notice extends EmberObject {
  /** @type {string | import("@ember/template").TrustedHTML | null} */
  text = null;

  /** @type {string | null} */
  id = null;

  /** @type {NoticeOptions | null} */
  options = null;

  init() {
    super.init(...arguments);

    const defaults = {
      // can this banner be hidden
      dismissable: false,
      // prepend html content
      html: null,
      // will define the style of the banner, follows alerts styling
      level: "info",
      // should the banner be permanently hidden?
      persistentDismiss: true,
      // callback function when dismissing a banner
      onDismiss: null,
      // show/hide banner function, will take precedence over everything
      visibility: null,
      // how long before banner should show again, eg: moment.duration(1, "week")
      dismissDuration: null,
    };

    this.options = this.set(
      "options",
      Object.assign(defaults, this.options || {})
    );
  }
}

export default class GlobalNotice extends Component {
  @service currentUser;
  @service keyValueStore;
  @service("logsNotice") logsNoticeService;
  @service router;
  @service session;
  @service site;
  @service siteSettings;

  get visible() {
    return !this.router.currentRouteName.startsWith("wizard.");
  }

  get #isEmailRelatedRoute() {
    const routeName = this.router.currentRouteName;
    return (
      routeName?.startsWith("admin") ||
      routeName?.startsWith("review") ||
      routeName?.startsWith("account-created") ||
      routeName?.startsWith("invites") ||
      routeName?.startsWith("userInvited") ||
      routeName === "login" ||
      routeName === "preferences.email" ||
      routeName === "preferences.emails" ||
      routeName === "preferences.notifications" ||
      routeName === "preferences.security"
    );
  }

  get notices() {
    let notices = [];

    if (cookie("dosp") === "1") {
      removeCookie("dosp", { path: "/" });
      notices.push(
        Notice.create({
          text: this.siteSettings.login_required
            ? i18n("forced_anonymous_login_required")
            : i18n("forced_anonymous"),
          id: "forced-anonymous",
        })
      );
    }

    if (this.session.get("safe_mode")) {
      notices.push(
        Notice.create({ text: i18n("safe_mode.enabled"), id: "safe-mode" })
      );
    }

    if (this.site.get("isStaffWritesOnly")) {
      notices.push(
        Notice.create({
          text: this.currentUser
            ? i18n("staff_writes_only_mode.enabled")
            : i18n("staff_writes_only_mode.enabled_anonymous"),
          id: "alert-staff-writes-only",
        })
      );
    } else if (this.site.get("isReadOnly")) {
      notices.push(
        Notice.create({
          text: this.currentUser
            ? i18n("read_only_mode.enabled")
            : i18n("read_only_mode.enabled_anonymous"),
          id: "alert-read-only",
        })
      );
    } else if (this.siteSettings.site_archived) {
      notices.push(
        Notice.create({
          text: this.currentUser
            ? i18n("site_archived.enabled")
            : i18n("site_archived.enabled_anonymous"),
          id: "alert-site-archived",
        })
      );
    }

    const previewThemeId =
      this.router.currentRoute?.queryParams?.preview_theme_id;
    if (previewThemeId) {
      if (currentThemeId() === parseInt(previewThemeId, 10)) {
        notices.push(
          Notice.create({
            text: i18n("theme_preview_notice"),
            id: "theme-preview",
          })
        );
      } else {
        notices.push(
          Notice.create({
            text: i18n("theme_preview_failed"),
            id: "theme-preview-failed",
            options: {
              level: "error",
            },
          })
        );
      }
    }

    if (this.siteSettings.disable_emails === "yes") {
      notices.push(
        Notice.create({
          text: i18n("emails_are_disabled"),
          id: "alert-emails-disabled",
        })
      );
    } else if (this.siteSettings.disable_emails === "non-staff") {
      notices.push(
        Notice.create({
          text: i18n("emails_are_disabled_non_staff"),
          id: "alert-emails-disabled",
        })
      );
    } else if (this.site.email_configured === false && !isDevelopment()) {
      notices.push(
        Notice.create({
          text: i18n("emails_are_disabled_no_smtp"),
          id: "alert-emails-disabled",
          options: {
            visibility: () => this.#isEmailRelatedRoute,
          },
        })
      );
    }

    if (this.siteSettings.global_notice?.length > 0) {
      notices.push(
        Notice.create({
          text: this.siteSettings.global_notice,
          id: "alert-global-notice",
        })
      );
    }

    const logsNotice = this.logsNoticeService;
    if (!logsNotice.hidden) {
      notices.push(
        Notice.create({
          text: logsNotice.message,
          id: "alert-logs-notice",
          options: {
            dismissable: true,
            persistentDismiss: false,
            onDismiss: () => logsNotice.set("text", ""),
          },
        })
      );
    }

    return notices.concat(Array.from(_pluginNotices)).filter((notice) => {
      if (notice.options.visibility) {
        return notice.options.visibility(notice);
      }

      const key = `${GLOBAL_NOTICE_DISMISSED_PROMPT_KEY}-${notice.id}`;
      const value = this.keyValueStore.get(key);

      // banner has never been dismissed
      if (!value) {
        return true;
      }

      // banner has no persistent dismiss and should always show on load
      if (!notice.options.persistentDismiss) {
        return true;
      }

      if (notice.options.dismissDuration) {
        const resetAt = moment(value).add(notice.options.dismissDuration);
        return moment().isAfter(resetAt);
      } else {
        return false;
      }
    });
  }

  @action
  dismissNotice(notice) {
    notice.options.onDismiss?.(notice);

    if (notice.options.persistentDismiss) {
      this.keyValueStore.set({
        key: `${GLOBAL_NOTICE_DISMISSED_PROMPT_KEY}-${notice.id}`,
        value: moment().toISOString(true),
      });
    }

    const alert = document.getElementById(`global-notice-${notice.id}`);
    if (alert) {
      alert.style.display = "none";
    }
  }

  <template>
    <div class="global-notice">
      {{#if this.visible}}
        {{#each this.notices as |notice|}}
          <div class="row">
            <div
              class="alert alert-{{notice.options.level}} {{notice.id}}"
              id="global-notice-{{notice.id}}"
            >
              {{#if notice.options.html}}
                {{trustHTML notice.options.html}}
              {{/if}}

              <span class="text">{{trustHTML notice.text}}</span>

              {{#if notice.options.dismissable}}
                <DButton
                  class="btn-transparent close"
                  @action={{fn this.dismissNotice notice}}
                  @icon="xmark"
                />
              {{/if}}
            </div>
          </div>
        {{/each}}
      {{/if}}
    </div>
  </template>
}
