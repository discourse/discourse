import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { popupAjaxError } from "discourse/lib/ajax-error";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import SiteSetting from "admin/models/site-setting";
import PluginCommitHash from "./plugin-commit-hash";

export default class AdminPluginsListItem extends Component {
  @service session;
  @service currentUser;
  @service sidebarState;

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

  get isAdminSearchFiltered() {
    if (!this.sidebarState.filter) {
      return false;
    }
    return this.args.plugin.nameTitleizedLower.match(this.sidebarState.filter);
  }

  get showPluginSettingsButton() {
    return this.currentUser.admin && this.args.plugin.hasSettings;
  }

  get disablePluginSettingsButton() {
    return (
      this.showPluginSettingsButton && this.args.plugin.hasOnlyEnabledSetting
    );
  }

  get settingsButtonTitle() {
    if (this.disablePluginSettingsButton) {
      return i18n("admin.plugins.settings_disabled");
    }

    return "";
  }

  <template>
    <tr
      data-plugin-name={{@plugin.name}}
      class={{concat
        "admin-plugins-list__row"
        (if this.isAdminSearchFiltered "-admin-search-filtered")
      }}
    >
      <td class="admin-plugins-list__name-details">
        <div class="admin-plugins-list__name-with-badges">
          <div class="admin-plugins-list__name">
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
            {{#if @plugin.label}}
              <span class="admin-plugins-list__badge">
                {{@plugin.label}}
              </span>
            {{/if}}
          </div>
        </div>
        <div class="admin-plugins-list__author">
          {{@plugin.author}}
        </div>
        <div class="admin-plugins-list__about">
          {{@plugin.about}}
          {{#if @plugin.linkUrl}}
            <a
              href={{@plugin.linkUrl}}
              rel="noopener noreferrer"
              target="_blank"
            >
              {{i18n "admin.plugins.learn_more"}}
            </a>
          {{/if}}
        </div>
      </td>
      <td class="admin-plugins-list__version">
        <div class="label">{{i18n "admin.plugins.version"}}</div>
        {{@plugin.version}}<br />
        <PluginCommitHash @plugin={{@plugin}} />
      </td>
      <td class="admin-plugins-list__enabled">
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
      <td class="admin-plugins-list__settings">
        {{#if this.showPluginSettingsButton}}
          {{#if @plugin.useNewShowRoute}}
            <LinkTo
              class="btn-default btn btn-icon-text"
              @route="adminPlugins.show"
              @model={{@plugin}}
              @disabled={{this.disablePluginSettingsButton}}
              title={{this.settingsButtonTitle}}
              data-plugin-setting-button={{@plugin.name}}
            >
              {{icon "cog"}}
              {{i18n "admin.plugins.change_settings_short"}}
            </LinkTo>
          {{else}}
            <LinkTo
              class="btn-default btn btn-icon-text"
              @route="adminSiteSettingsCategory"
              @model={{@plugin.settingCategoryName}}
              @query={{hash filter=(concat "plugin:" @plugin.name)}}
              @disabled={{this.disablePluginSettingsButton}}
              title={{this.settingsButtonTitle}}
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
