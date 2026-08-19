import Component from "@glimmer/component";
import { LinkTo } from "@ember/routing";
import { trustHTML } from "@ember/template";
import DashboardSection from "discourse/admin/components/dashboard/section";
import VersionCheck from "discourse/admin/models/version-check";
import dashIfEmpty from "discourse/helpers/dash-if-empty";
import getUrl from "discourse/lib/get-url";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import I18n, { i18n } from "discourse-i18n";

const PREFIX = "admin.dashboard.sections.system";

export default class DashboardSystem extends Component {
  get versionCheck() {
    const version = this.args.data?.version;
    return version ? new VersionCheck(version) : null;
  }

  get versionStatus() {
    const check = this.versionCheck;

    if (
      check.noCheckPerformed ||
      (check.stale_data && !check.version_check_pending)
    ) {
      return {
        icon: "triangle-exclamation",
        className: "--critical",
        message: i18n(`${PREFIX}.update_check_failed`),
      };
    }

    if (check.stale_data) {
      return {
        icon: "circle-check",
        className: "--ok",
        message: i18n("admin.dashboard.version_check_pending"),
      };
    }

    if (check.upToDate) {
      return {
        icon: "circle-check",
        className: "--ok",
        message: check.newerCommitsAvailable
          ? i18n("admin.dashboard.up_to_date_newer_commits", {
              count: check.newChangesCount,
            })
          : i18n("admin.dashboard.up_to_date"),
      };
    }

    return {
      icon: "triangle-exclamation",
      className: "--warning",
      message: check.latest_version
        ? i18n(`${PREFIX}.update_available`, { version: check.latest_version })
        : i18n("admin.dashboard.updates_available"),
    };
  }

  get backups() {
    return this.args.data?.storage?.backups;
  }

  get uploads() {
    return this.args.data?.storage?.uploads;
  }

  get #usedBytes() {
    return (this.backups?.used_bytes ?? 0) + (this.uploads?.used_bytes ?? 0);
  }

  get #freeBytes() {
    return this.uploads?.free_bytes ?? this.backups?.free_bytes ?? null;
  }

  get usedSpace() {
    return I18n.toHumanSize(this.#usedBytes);
  }

  get freeSpace() {
    const free = this.#freeBytes;
    return free == null ? null : I18n.toHumanSize(free);
  }

  get barStyle() {
    const free = this.#freeBytes;

    if (free == null) {
      return null;
    }

    const total = this.#usedBytes + free;
    const percent = total === 0 ? 0 : (this.#usedBytes / total) * 100;

    return trustHTML(`width: ${Math.min(100, percent).toFixed(1)}%`);
  }

  get barLabel() {
    return i18n("admin.dashboard.space_used_and_free", {
      usedSize: this.usedSpace,
      freeSize: this.freeSpace,
    });
  }

  get hasStatus() {
    return !!(
      this.args.data?.discourse_updated_at ||
      this.args.data?.dashboard_updated_at
    );
  }

  get backupsSummary() {
    return i18n(`${PREFIX}.backups_size`, {
      count: this.backups.count,
      size: I18n.toHumanSize(this.backups.used_bytes),
    });
  }

  get uploadsSummary() {
    return i18n(`${PREFIX}.uploads_size`, {
      size: I18n.toHumanSize(this.uploads?.used_bytes ?? 0),
    });
  }

  <template>
    <DashboardSection
      @title={{i18n "admin.dashboard.sections.system.title"}}
      @layout="row"
      ...attributes
    >
      {{#if @fetchError}}
        <div class="db-section__error" role="alert">
          {{i18n "admin.dashboard.sections.system.fetch_error"}}
        </div>
      {{else if @data}}
        {{#if this.versionCheck}}
          <div class="db-section__row-block db-system__block">
            <div class="db-section__row-block-header">
              <h3 class="db-section__header">
                {{dIcon "tag" class="db-system__block-icon"}}
                {{i18n "admin.dashboard.version"}}
              </h3>
            </div>

            <div class="db-system__headline">

              <div class="db-group">
                <div class="db-system__value">
                  {{dashIfEmpty this.versionCheck.installed_version}}
                </div>

                {{#if this.versionCheck.installedCommitsAhead}}
                  <span
                    class="db-pill"
                    title={{i18n
                      "admin.dashboard.commits_ahead"
                      count=this.versionCheck.installedCommitsAhead
                    }}
                  >
                    {{i18n
                      "admin.dashboard.sections.system.commits"
                      count=this.versionCheck.installedCommitsAhead
                    }}
                  </span>
                {{/if}}
              </div>

              {{#if this.versionCheck.gitLink}}
                <a
                  class="db-system__link"
                  href={{this.versionCheck.gitLink}}
                  rel="noopener noreferrer"
                  target="_blank"
                  title={{i18n
                    "admin.dashboard.commit_on_github"
                    sha=this.versionCheck.shortSha
                  }}
                >
                  {{i18n "admin.dashboard.sections.system.view_on_github"}}
                  {{dIcon "up-right-from-square"}}
                </a>
              {{/if}}

            </div>

            <div
              class={{dConcatClass
                "db-system__footer"
                this.versionStatus.className
              }}
            >
              <span class="db-system__label">
                {{dIcon this.versionStatus.icon class="db-system__status-icon"}}
                {{this.versionStatus.message}}
              </span>
            </div>
          </div>
        {{/if}}

        {{#if @data.storage}}
          <div class="db-section__row-block db-system__block --storage">
            <div class="db-section__row-block-header">
              <h3 class="db-section__header">
                {{dIcon "database" class="db-system__block-icon"}}
                {{i18n "admin.dashboard.sections.system.storage"}}
              </h3>
            </div>

            <div class="db-system__headline">
              <div class="db-system__value">
                {{i18n "admin.dashboard.space_used" usedSize=this.usedSpace}}
              </div>
              {{#if this.freeSpace}}
                <div class="db-system__label">
                  {{i18n
                    "admin.dashboard.sections.system.space_free"
                    size=this.freeSpace
                  }}
                </div>
              {{/if}}
            </div>

            <div>
              {{#if this.barStyle}}
                <div
                  class="db-bar-track"
                  role="img"
                  aria-label={{this.barLabel}}
                >
                  <span class="db-bar-fill" style={{this.barStyle}}></span>
                </div>
              {{/if}}

              <div class="db-system__breakdown">
                {{#if this.backups}}
                  <span class="db-system__breakdown-item">
                    {{this.backupsSummary}}
                  </span>
                  <span class="dot-separator"></span>
                {{/if}}
                <span class="db-system__breakdown-item">
                  {{this.uploadsSummary}}
                </span>
              </div>
            </div>

            {{#if this.backups}}
              <div class="db-system__footer">
                {{#if this.backups.last_backup_taken_at}}
                  <div class="db-system__label">
                    <span>{{trustHTML
                        (i18n
                          "admin.dashboard.sections.system.latest_backup"
                          date=(dFormatDate
                            this.backups.last_backup_taken_at leaveAgo="true"
                          )
                        )
                      }}</span>
                  </div>
                {{/if}}
                <a class="db-system__link" href={{getUrl "/admin/backups"}}>
                  {{i18n "admin.dashboard.sections.system.manage_backups"}}
                </a>
              </div>
            {{/if}}
          </div>
        {{/if}}

        {{#if this.hasStatus}}
          <div class="db-section__row-block db-system__block --status">
            <div class="db-section__row-block-header">
              <h3 class="db-section__header">
                {{dIcon "clock" class="db-system__block-icon"}}
                {{i18n "admin.dashboard.sections.system.status"}}
              </h3>
            </div>

            {{#if @data.discourse_updated_at}}
              <div class="db-system__headline">
                <div class="db-system__value">
                  {{dFormatDate @data.discourse_updated_at leaveAgo="true"}}
                </div>
                <div class="db-system__label">
                  {{i18n "admin.dashboard.sections.system.discourse_updated"}}
                </div>
              </div>
            {{/if}}

            {{#if @data.dashboard_updated_at}}
              <div class="db-system__headline">
                <div class="db-system__value">
                  {{dFormatDate @data.dashboard_updated_at leaveAgo="true"}}
                </div>
                <div class="db-system__label">
                  {{i18n "admin.dashboard.sections.system.dashboard_updated"}}
                </div>
              </div>
            {{/if}}

            <div class="db-system__footer">
              <LinkTo @route="admin.whatsNew" class="db-system__link">
                {{i18n "admin.dashboard.whats_new_in_discourse"}}
              </LinkTo>
            </div>
          </div>
        {{/if}}
      {{/if}}
    </DashboardSection>
  </template>
}
