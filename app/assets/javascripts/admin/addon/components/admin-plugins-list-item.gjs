import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import PluginOutlet from "discourse/components/plugin-outlet";
import icon from "discourse/helpers/d-icon";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
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

  get isPreinstalled() {
    return this.args.plugin.url?.includes(
      "/discourse/discourse/tree/main/plugins/"
    );
  }

  <template>
    <tr
      data-plugin-name={{@plugin.name}}
      class={{concat
        "d-table__row admin-plugins-list__row"
        (if this.isAdminSearchFiltered "-admin-search-filtered")
      }}
    >
      <td class="d-table__cell --overview admin-plugins-list__name-details">
        <div class="admin-plugins-list__name-with-badges">
          <div class="d-admin-row__overview-name admin-plugins-list__name">
            {{@plugin.nameTitleized}}
          </div>

          <div class="badges">
            {{#if @plugin.label}}
              <span class="admin-plugins-list__badge">
                {{@plugin.label}}
              </span>
            {{/if}}
          </div>

          <PluginOutlet
            @name="admin-plugin-list-name-badge-after"
            @connectorTagName="span"
            @outletArgs={{lazyHash plugin=@plugin}}
          />
        </div>
        <div class="d-admin-row__overview-author admin-plugins-list__author">
          {{@plugin.author}}
        </div>
        <div class="d-admin-row__overview-about admin-plugins-list__about">
          {{@plugin.about}}
          {{#if @plugin.linkUrl}}
            <a
              href={{@plugin.linkUrl}}
              rel="noopener noreferrer"
              target="_blank"
              class="admin-plugins-list__about-link"
            >
              {{icon "up-right-from-square"}}
              {{i18n "admin.plugins.learn_more"}}
            </a>
          {{/if}}
        </div>
      </td>
      <td class="d-table__cell --detail admin-plugins-list__version">
        <div class="d-table__mobile-label">
          {{i18n "admin.plugins.version"}}
        </div>
        <div class="plugin-version">
          <PluginOutlet
            @name="admin-plugin-list-item-version"
            @outletArgs={{lazyHash plugin=@plugin}}
          >
            {{@plugin.version}}<br />
            {{#if this.isPreinstalled}}
              <span class="admin-plugins-list__preinstalled">
                {{i18n "admin.plugins.preinstalled"}}
              </span>
            {{else}}
              <PluginCommitHash @plugin={{@plugin}} />
            {{/if}}
          </PluginOutlet>
        </div>
      </td>
      <td class="d-table__cell --detail admin-plugins-list__enabled">
        <div class="d-table__mobile-label">
          {{i18n "admin.plugins.enabled"}}
        </div>
        <PluginOutlet
          @name="admin-plugin-list-item-enabled"
          @outletArgs={{lazyHash plugin=@plugin}}
        >
          {{#if @plugin.enabledSetting}}
            <DToggleSwitch
              @state={{@plugin.enabled}}
              {{on "click" (fn this.togglePluginEnabled @plugin)}}
            />
          {{else}}
            <DToggleSwitch @state={{@plugin.enabled}} disabled={{true}} />
          {{/if}}
        </PluginOutlet>
      </td>
      <td class="d-table__cell --controls admin-plugins-list__settings">
        <PluginOutlet
          @name="admin-plugin-list-item-settings"
          @outletArgs={{lazyHash plugin=@plugin}}
        >
          {{#if this.showPluginSettingsButton}}
            {{#if @plugin.useNewShowRoute}}
              <LinkTo
                class="btn btn-default btn-text btn-small"
                @route="adminPlugins.show"
                @model={{@plugin}}
                @disabled={{this.disablePluginSettingsButton}}
                title={{this.settingsButtonTitle}}
                data-plugin-setting-button={{@plugin.name}}
              >
                {{i18n "admin.plugins.change_settings_short"}}
              </LinkTo>
            {{else}}
              <LinkTo
                class="btn btn-default btn-text btn-small"
                @route="adminSiteSettingsCategory"
                @model={{@plugin.settingCategoryName}}
                @query={{hash filter=(concat "plugin:" @plugin.name)}}
                @disabled={{this.disablePluginSettingsButton}}
                title={{this.settingsButtonTitle}}
                data-plugin-setting-button={{@plugin.name}}
              >
                {{i18n "admin.plugins.change_settings_short"}}
              </LinkTo>
            {{/if}}
          {{/if}}
        </PluginOutlet>
      </td>
    </tr>
  </template>
}
