import Component from "@glimmer/component";
import { concat, fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import PluginOutlet from "discourse/components/plugin-outlet";
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
        "d-admin-row__content admin-plugins-list__row"
        (if this.isAdminSearchFiltered "-admin-search-filtered")
      }}
    >
      <td class="d-admin-row__overview admin-plugins-list__name-details">
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
            @outletArgs={{hash plugin=@plugin}}
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
            >
              {{i18n "admin.plugins.learn_more"}}
              {{icon "up-right-from-square"}}
            </a>
          {{/if}}
        </div>
      </td>
      <td class="d-admin-row__detail admin-plugins-list__version">
        <div class="d-admin-row__mobile-label">
          {{i18n "admin.plugins.version"}}
        </div>
        <div class="plugin-version">
          <PluginOutlet
            @name="admin-plugin-list-item-version"
            @outletArgs={{hash plugin=@plugin}}
          >
            {{@plugin.version}}<br />
            <PluginCommitHash @plugin={{@plugin}} />
          </PluginOutlet>
        </div>
      </td>
      <td class="d-admin-row__detail admin-plugins-list__enabled">
        <div class="d-admin-row__mobile-label">
          {{i18n "admin.plugins.enabled"}}
        </div>
        <PluginOutlet
          @name="admin-plugin-list-item-enabled"
          @outletArgs={{hash plugin=@plugin}}
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
      <td class="d-admin-row__controls admin-plugins-list__settings">
        <PluginOutlet
          @name="admin-plugin-list-item-settings"
          @outletArgs={{hash plugin=@plugin}}
        >
          {{#if this.showPluginSettingsButton}}
            {{#if @plugin.useNewShowRoute}}
              <LinkTo
                class="btn btn-text btn-small"
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
                class="btn btn-text btn-small"
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
