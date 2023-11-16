import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { inject as service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import SiteSetting from "admin/models/site-setting";
import PluginCommitHash from "./plugin-commit-hash";

export default class AdminPluginsListItem extends Component {
  @service session;
  @service currentUser;

  @action
  async togglePluginEnabled(plugin) {
    const oldValue = plugin.enabled;
    const newValue = !oldValue;

    try {
      plugin.enabled = newValue;
      await SiteSetting.update(plugin.enabledSetting, newValue);
      this.session.requiresRefresh = true;
    } catch (err) {
      plugin.enabled = oldValue;
      popupAjaxError(err);
    }
  }

  <template>
    <tr data-plugin-name={{@plugin.name}}>
      <td class="plugin-details">
        <div class="name-with-badges">
          <div class="name">
            {{#if @plugin.linkUrl}}
              <a
                href={{@plugin.linkUrl}}
                rel="noopener noreferrer"
                target="_blank"
              >{{@plugin.nameTitleized}}</a>
            {{else}}
              {{@plugin.nameTitleized}}
            {{/if}}
          </div>

          <div class="badges">
            {{#if @plugin.isExperimental}}
              <span
                class="plugin-badge -experimental"
                title={{i18n "admin.plugins.experimental"}}
              >
                {{i18n "admin.plugins.experimental_badge"}}
              </span>
            {{/if}}
          </div>
        </div>
        <div class="author">
          {{@plugin.author}}
          {{#if @plugin.isOfficial}}
            {{icon "fab-discourse"}}
          {{/if}}
        </div>
        <div class="about">
          {{@plugin.about}}
          {{#if @plugin.linkUrl}}
            <a
              href={{@plugin.linkUrl}}
              rel="noopener noreferrer"
              target="_blank"
            >
              {{i18n "learn_more"}}
            </a>
          {{/if}}
        </div>
      </td>
      <td class="version">
        <div class="label">{{i18n "admin.plugins.version"}}</div>
        {{@plugin.version}}<br />
        <PluginCommitHash @plugin={{@plugin}} />
      </td>
      <td class="col-enabled">
        <div class="label">{{i18n "admin.plugins.enabled"}}</div>
        {{#if @plugin.enabledSetting}}
          <DToggleSwitch
            @state={{@plugin.enabled}}
            {{on "click" (fn this.togglePluginEnabled @plugin)}}
          />
        {{else}}
          <DToggleSwitch @state={{@plugin.enabled}} disabled={{true}} />
        {{/if}}
      </td>
      <td class="settings">
        {{#if this.currentUser.admin}}
          {{#if @plugin.hasSettings}}
            <LinkTo
              class="btn-default btn btn-icon-text"
              @route="adminSiteSettingsCategory"
              @model={{@plugin.settingCategoryName}}
              @query={{hash filter=(concat "plugin:" @plugin.name)}}
              data-plugin-setting-button={{@plugin.name}}
            >
              {{icon "cog"}}
              {{i18n "admin.plugins.change_settings_short"}}
            </LinkTo>
          {{/if}}
        {{/if}}
      </td>
    </tr>
  </template>
}
