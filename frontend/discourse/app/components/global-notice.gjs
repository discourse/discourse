/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn } from "@ember/helper";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import cookie, { removeCookie } from "discourse/lib/cookie";
import { bind } from "discourse/lib/decorators";
import { currentThemeId } from "discourse/lib/theme-selector";
import { DeferredTrackedSet } from "discourse/lib/tracked-tools";
import { i18n } from "discourse-i18n";

const _pluginNotices = new DeferredTrackedSet();

export function addGlobalNotice(text, id, options = {}) {
  _pluginNotices.add(Notice.create({ text, id, options }));
}

const GLOBAL_NOTICE_DISMISSED_PROMPT_KEY = "dismissed-global-notice-v2";

class Notice extends EmberObject {
  text = null;
  id = null;
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

@tagName("")
export default class GlobalNotice extends Component {
  @service keyValueStore;
  @service("logsNotice") logsNoticeService;
  @service router;

  logNotice = null;

  constructor() {
    super(...arguments);

    this.logsNoticeService.addObserver("hidden", this._handleLogsNoticeUpdate);
    this.logsNoticeService.addObserver("text", this._handleLogsNoticeUpdate);
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);

    this.logsNoticeService.removeObserver("text", this._handleLogsNoticeUpdate);
    this.logsNoticeService.removeObserver(
      "hidden",
      this._handleLogsNoticeUpdate
    );
  }

  get visible() {
    return !this.router.currentRouteName.startsWith("wizard.");
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
          text: i18n("staff_writes_only_mode.enabled"),
          id: "alert-staff-writes-only",
        })
      );
    } else if (this.site.get("isReadOnly")) {
      notices.push(
        Notice.create({
          text: i18n("read_only_mode.enabled"),
          id: "alert-read-only",
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
          options: {
            dismissable: true,
            persistentDismiss: false,
          },
        })
      );
    } else if (this.siteSettings.disable_emails === "non-staff") {
      notices.push(
        Notice.create({
          text: i18n("emails_are_disabled_non_staff"),
          id: "alert-emails-disabled",
          options: {
            dismissable: true,
            persistentDismiss: false,
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

    if (this.get("logNotice")) {
      notices.push(this.get("logNotice"));
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

  @bind
  _handleLogsNoticeUpdate() {
    const logNotice = Notice.create({
      text: htmlSafe(this.logsNoticeService.message),
      id: "alert-logs-notice",
      options: {
        dismissable: true,
        persistentDismiss: false,
        visibility: () => !this.logsNoticeService.hidden,
        onDismiss: () => this.logsNoticeService.set("text", ""),
      },
    });

    this.set("logNotice", logNotice);
  }

  <template>
    <div class="global-notice">
      {{#if this.visible}}
        {{#each this.notices as |notice|}}
          <div class="row">
            <div
              id="global-notice-{{notice.id}}"
              class="alert alert-{{notice.options.level}} {{notice.id}}"
            >
              {{#if notice.options.html}}
                {{htmlSafe notice.options.html}}
              {{/if}}

              <span class="text">{{htmlSafe notice.text}}</span>

              {{#if notice.options.dismissable}}
                <DButton
                  @icon="xmark"
                  @action={{fn this.dismissNotice notice}}
                  class="btn-transparent close"
                />
              {{/if}}
            </div>
          </div>
        {{/each}}
      {{/if}}
    </div>
  </template>
}
