import EmberObject, { action } from "@ember/object";
import cookie, { removeCookie } from "discourse/lib/cookie";
import Component from "@ember/component";
import I18n from "I18n";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import { htmlSafe } from "@ember/template";
import { inject as service } from "@ember/service";

const _pluginNotices = [];

export function addGlobalNotice(text, id, options = {}) {
  _pluginNotices.push(Notice.create({ text, id, options }));
}

const GLOBAL_NOTICE_DISMISSED_PROMPT_KEY = "dismissed-global-notice-v2";

const Notice = EmberObject.extend({
  logsNoticeService: service("logsNotice"),

  text: null,
  id: null,
  options: null,

  init() {
    this._super(...arguments);

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
  },
});

export default Component.extend({
  logsNoticeService: service("logsNotice"),
  logNotice: null,

  init() {
    this._super(...arguments);

    this.logsNoticeService.addObserver("hidden", this._handleLogsNoticeUpdate);
    this.logsNoticeService.addObserver("text", this._handleLogsNoticeUpdate);
  },

  willDestroyElement() {
    this._super(...arguments);

    this.logsNoticeService.removeObserver("text", this._handleLogsNoticeUpdate);
    this.logsNoticeService.removeObserver(
      "hidden",
      this._handleLogsNoticeUpdate
    );
  },

  @discourseComputed(
    "site.isReadOnly",
    "site.wizard_required",
    "siteSettings.login_required",
    "siteSettings.disable_emails",
    "siteSettings.global_notice",
    "siteSettings.bootstrap_mode_enabled",
    "siteSettings.bootstrap_mode_min_users",
    "session.safe_mode",
    "logNotice.{id,text,hidden}"
  )
  notices(
    isReadOnly,
    wizardRequired,
    loginRequired,
    disableEmails,
    globalNotice,
    bootstrapModeEnabled,
    bootstrapModeMinUsers,
    safeMode,
    logNotice
  ) {
    let notices = [];

    if (cookie("dosp") === "1") {
      removeCookie("dosp", { path: "/" });
      notices.push(
        Notice.create({
          text: loginRequired
            ? I18n.t("forced_anonymous_login_required")
            : I18n.t("forced_anonymous"),
          id: "forced-anonymous",
        })
      );
    }

    if (safeMode) {
      notices.push(
        Notice.create({ text: I18n.t("safe_mode.enabled"), id: "safe-mode" })
      );
    }

    if (isReadOnly) {
      notices.push(
        Notice.create({
          text: I18n.t("read_only_mode.enabled"),
          id: "alert-read-only",
        })
      );
    }

    if (disableEmails === "yes" || disableEmails === "non-staff") {
      notices.push(
        Notice.create({
          text: I18n.t("emails_are_disabled"),
          id: "alert-emails-disabled",
        })
      );
    }

    if (wizardRequired) {
      const requiredText = I18n.t("wizard_required", {
        url: getURL("/wizard"),
      });
      notices.push(
        Notice.create({ text: htmlSafe(requiredText), id: "alert-wizard" })
      );
    }

    if (this.currentUser?.staff && bootstrapModeEnabled) {
      if (bootstrapModeMinUsers > 0) {
        notices.push(
          Notice.create({
            text: I18n.t("bootstrap_mode_enabled", {
              count: bootstrapModeMinUsers,
            }),
            id: "alert-bootstrap-mode",
          })
        );
      } else {
        notices.push(
          Notice.create({
            text: I18n.t("bootstrap_mode_disabled"),
            id: "alert-bootstrap-mode",
          })
        );
      }
    }

    if (globalNotice?.length > 0) {
      notices.push(
        Notice.create({
          text: globalNotice,
          id: "alert-global-notice",
        })
      );
    }

    if (logNotice) {
      notices.push(logNotice);
    }

    return notices.concat(_pluginNotices).filter((notice) => {
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
  },

  @action
  dismissNotice(notice) {
    if (notice.options.onDismiss) {
      notice.options.onDismiss(notice);
    }

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
  },

  @bind
  _handleLogsNoticeUpdate() {
    const { logsNoticeService } = this;
    const logNotice = Notice.create({
      text: htmlSafe(this.logsNoticeService.message),
      id: "alert-logs-notice",
      options: {
        dismissable: true,
        persistentDismiss: false,
        visibility() {
          return !logsNoticeService.hidden;
        },
        onDismiss() {
          logsNoticeService.set("text", "");
        },
      },
    });

    this.set("logNotice", logNotice);
  },
});
