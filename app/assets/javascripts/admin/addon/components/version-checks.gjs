import Component from "@ember/component";
import CustomHtml from "discourse/components/custom-html";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import dashIfEmpty from "discourse/helpers/dash-if-empty";
import lazyHash from "discourse/helpers/lazy-hash";
import { i18n } from "discourse-i18n";

export default class VersionChecks extends Component {
  <template>
    <div class="section-title">
      <h2>
        {{i18n "admin.dashboard.version"}}
      </h2>
    </div>

    <div
      class="dashboard-stats version-check
        {{if this.versionCheck.critical_updates 'critical' 'normal'}}"
    >
      <div class="version-number">
        <h4>
          {{i18n "admin.dashboard.installed_version"}}
        </h4>
        <h3>
          {{dashIfEmpty this.versionCheck.installed_version}}
        </h3>
        {{#if this.versionCheck.gitLink}}
          <div class="sha-link">
            (
            <a
              href={{this.versionCheck.gitLink}}
              rel="noopener noreferrer"
              target="_blank"
            >
              {{this.versionCheck.shortSha}}
            </a>
            )
          </div>
        {{/if}}
      </div>
      {{#if this.versionCheck.noCheckPerformed}}
        <div class="version-number">
          <h4>
            {{i18n "admin.dashboard.latest_version"}}
          </h4>
          <h3>
            —
          </h3>
        </div>
        <div class="version-status">
          <div class="face">
            <span class="icon critical-updates-available">
              {{icon "far-face-frown"}}
            </span>
          </div>
          <div class="version-notes">
            <span class="normal-note">
              {{i18n "admin.dashboard.no_check_performed"}}
            </span>
          </div>
        </div>
      {{else if this.versionCheck.stale_data}}
        <div class="version-number">
          <h4>
            {{i18n "admin.dashboard.latest_version"}}
          </h4>
          <h3>
            {{#if this.versionCheck.version_check_pending}}
              {{dashIfEmpty this.versionCheck.installed_version}}
            {{/if}}
          </h3>
        </div>
        <div class="version-status">
          <div class="face">
            {{#if this.versionCheck.version_check_pending}}
              <span class="icon up-to-date">
                {{icon "far-face-smile"}}
              </span>
            {{else}}
              <span class="icon critical-updates-available">
                {{icon "far-face-frown"}}
              </span>
            {{/if}}
          </div>
          <div class="version-notes">
            <span class="normal-note">
              {{#if this.versionCheck.version_check_pending}}
                {{i18n "admin.dashboard.version_check_pending"}}
              {{else}}
                {{i18n "admin.dashboard.stale_data"}}
              {{/if}}
            </span>
          </div>
        </div>
      {{else}}
        <div class="version-number">
          <h4>
            {{i18n "admin.dashboard.latest_version"}}
          </h4>
          <h3>
            {{dashIfEmpty this.versionCheck.latest_version}}
          </h3>
        </div>
        <div class="version-status">
          <div class="face">
            {{#if this.versionCheck.upToDate}}
              <span class="icon up-to-date">
                {{icon "far-face-smile"}}
              </span>
            {{else}}
              <span
                class="icon
                  {{if
                    this.versionCheck.critical_updates
                    'critical-updates-available'
                    'updates-available'
                  }}"
              >
                {{#if this.versionCheck.behindByOneVersion}}
                  {{icon "far-face-meh"}}
                {{else}}
                  {{icon "far-face-frown"}}
                {{/if}}
              </span>
            {{/if}}
          </div>
          <div class="version-notes">
            {{#if this.versionCheck.upToDate}}
              {{i18n "admin.dashboard.up_to_date"}}
            {{else}}
              <span class="critical-note">
                {{i18n "admin.dashboard.critical_available"}}
              </span>
              <span class="normal-note">
                {{i18n "admin.dashboard.updates_available"}}
              </span>
              {{i18n "admin.dashboard.please_update"}}
            {{/if}}
          </div>
        </div>
      {{/if}}

      <CustomHtml
        @name="update-header"
        @versionCheck={{this.versionCheck}}
        @tagName="div"
        @classNames="update-header"
      />

      <PluginOutlet
        @name="admin-upgrade-header"
        @outletArgs={{lazyHash versionCheck=this.versionCheck}}
      />
    </div>
  </template>
}
