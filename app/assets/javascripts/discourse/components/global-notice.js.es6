import { bind, cancel } from "@ember/runloop";
import Component from "@ember/component";
import LogsNotice from "discourse/services/logs-notice";
import EmberObject from "@ember/object";

const _pluginNotices = [];

export function addGlobalNotice(text, id, options = {}) {
  _pluginNotices.push(Notice.create({ text, id, options }));
}

const GLOBAL_NOTICE_DISMISSED_PROMPT_KEY = "dismissed-global-notice";

const Notice = EmberObject.extend({
  text: null,
  id: null,
  options: null,

  init() {
    this._super(...arguments);

    const defaults = {
      dismissable: false,
      html: null,
      level: "info",
      persistentDismiss: true,
      onDismiss: null,
      visibility: null
    };

    this.options = this.set(
      "options",
      Object.assign(defaults, this.options || {})
    );
  }
});

export default Component.extend({
  logNotice: null,

  init() {
    this._super(...arguments);

    this._setupObservers();
  },

  willDestroyElement() {
    this._super(...arguments);

    this._tearDownObservers();
  },

  notices: Ember.computed(
    "site.isReadOnly",
    "siteSettings.disable_emails",
    "logNotice.{id,text,hidden}",
    function() {
      let notices = [];

      if ($.cookie("dosp") === "1") {
        $.removeCookie("dosp", { path: "/" });
        notices.push(
          Notice.create({
            text: I18n.t("forced_anonymous"),
            id: "forced-anonymous"
          })
        );
      }

      if (this.session && this.session.safe_mode) {
        notices.push(
          Notice.create({ text: I18n.t("safe_mode.enabled"), id: "safe-mode" })
        );
      }

      if (this.site.isReadOnly) {
        notices.push(
          Notice.create({
            text: I18n.t("read_only_mode.enabled"),
            id: "alert-read-only"
          })
        );
      }

      if (
        this.siteSettings.disable_emails === "yes" ||
        this.siteSettings.disable_emails === "non-staff"
      ) {
        notices.push(
          Notice.create({
            text: I18n.t("emails_are_disabled"),
            id: "alert-emails-disabled"
          })
        );
      }

      if (this.site.wizard_required) {
        const requiredText = I18n.t("wizard_required", {
          url: Discourse.getURL("/wizard")
        });
        notices.push(Notice.create({ text: requiredText, id: "alert-wizard" }));
      }

      if (
        this.get("currentUser.staff") &&
        this.siteSettings.bootstrap_mode_enabled
      ) {
        if (this.siteSettings.bootstrap_mode_min_users > 0) {
          notices.push(
            Notice.create({
              text: I18n.t("bootstrap_mode_enabled", {
                min_users: this.siteSettings.bootstrap_mode_min_users
              }),
              id: "alert-bootstrap-mode"
            })
          );
        } else {
          notices.push(
            Notice.create({
              text: I18n.t("bootstrap_mode_disabled"),
              id: "alert-bootstrap-mode"
            })
          );
        }
      }

      if (
        this.siteSettings.global_notice &&
        this.siteSettings.global_notice.length
      ) {
        notices.push(
          Notice.create({
            text: this.siteSettings.global_notice.htmlSafe(),
            id: "alert-global-notice"
          })
        );
      }

      if (this.logNotice) {
        notices.push(this.logNotice);
      }

      return notices.concat(_pluginNotices).filter(notice => {
        if (notice.options.visibility) {
          return notice.options.visibility(notice);
        } else {
          const key = `${GLOBAL_NOTICE_DISMISSED_PROMPT_KEY}-${notice.id}`;
          return !this.keyValueStore.get(key);
        }
      });
    }
  ),

  actions: {
    dismissNotice(notice) {
      if (notice.options.onDismiss) {
        notice.options.onDismiss(notice);
      }

      if (notice.options.persistentDismiss) {
        this.keyValueStore.set({
          key: `${GLOBAL_NOTICE_DISMISSED_PROMPT_KEY}-${notice.id}`,
          value: true
        });
      }

      const alert = document.getElementById(`global-notice-${notice.id}`);
      if (alert) alert.style.display = "none";
    }
  },

  _setupObservers() {
    this._boundLogsNoticeHandler = bind(this, this._handleLogsNoticeUpdate);
    LogsNotice.current().addObserver("hidden", this._boundLogsNoticeHandler);
    LogsNotice.current().addObserver("text", this._boundLogsNoticeHandler);
  },

  _tearDownObservers() {
    if (this._boundLogsNoticeHandler) {
      LogsNotice.current().removeObserver("text", this._boundLogsNoticeHandler);
      LogsNotice.current().removeObserver(
        "hidden",
        this._boundLogsNoticeHandler
      );
      cancel(this._boundLogsNoticeHandler);
    }
  },

  _handleLogsNoticeUpdate() {
    const logNotice = Notice.create({
      text: LogsNotice.currentProp("message"),
      id: "alert-logs-notice",
      options: {
        dismissable: true,
        persistentDismiss: false,
        visibility() {
          return !LogsNotice.currentProp("hidden");
        },
        onDismiss() {
          LogsNotice.currentProp("hidden", true);
          LogsNotice.currentProp("text", "");
        }
      }
    });

    this.set("logNotice", logNotice);
  }
});
