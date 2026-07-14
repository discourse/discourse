import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DMenu from "discourse/float-kit/components/d-menu";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dFormatDate from "discourse/ui-kit/helpers/d-format-date";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const SCOPE_ICONS = {
  global: "globe",
  read_only: "eye",
  granular: "bullseye",
};

export default class ApiKeyItem extends Component {
  @service router;

  get scopeIcon() {
    return SCOPE_ICONS[this.args.apiKey.scope_mode];
  }

  get scopeName() {
    return i18n(`admin.api.scopes.${this.args.apiKey.scope_mode}`);
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  async revokeKey(key) {
    try {
      await key.revoke();
      await this.dMenu.close();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async undoRevokeKey(key) {
    try {
      await key.undoRevoke();
      await this.dMenu.close();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  edit() {
    this.router.transitionTo("adminApiKeys.show", this.args.apiKey.id);
  }

  <template>
    <tr class="d-table__row">
      <td class="d-table__cell --overview key">
        <div class="d-table__value-wrapper">
          {{@apiKey.truncatedKey}}
          {{#if @apiKey.revoked_at}}
            <div class="status-label --inactive">
              <div class="status-label-indicator"></div>
              <div class="status-label-text">
                {{i18n "admin.api.revoked"}}
              </div>
            </div>
          {{/if}}
        </div>
      </td>
      <td class="d-table__cell --detail key-description">
        <div class="d-table__mobile-label">{{i18n
            "admin.api.description"
          }}</div>
        {{@apiKey.shortDescription}}
      </td>
      <td class="d-table__cell --detail key-user">
        <div class="d-table__mobile-label">{{i18n "admin.api.user"}}</div>
        {{#if @apiKey.user}}
          <LinkTo @route="adminUser" @model={{@apiKey.user}}>
            {{dAvatar @apiKey.user imageSize="small"}}
          </LinkTo>
        {{else}}
          {{i18n "admin.api.all_users"}}
        {{/if}}
      </td>
      <td class="d-table__cell --detail key-created">
        <div class="d-table__mobile-label">{{i18n "admin.api.created"}}</div>
        <div class="d-table__value-wrapper">
          <LinkTo @route="adminUser" @model={{@apiKey.createdBy}}>
            {{dAvatar @apiKey.createdBy imageSize="small"}}
          </LinkTo>
          {{dFormatDate @apiKey.created_at}}
        </div>
      </td>
      <td class="d-table__cell --detail key-scope">
        <div class="d-table__mobile-label">{{i18n "admin.api.scope"}}</div>
        <div class="d-table__value-wrapper">
          {{dIcon this.scopeIcon}}
          {{this.scopeName}}
        </div>
      </td>
      <td class="d-table__cell --detail key-last-used">
        <div class="d-table__mobile-label">{{i18n "admin.api.last_used"}}</div>
        {{#if @apiKey.last_used_at}}
          {{dFormatDate @apiKey.last_used_at}}
        {{else}}
          {{i18n "admin.api.never_used"}}
        {{/if}}
      </td>
      <td class="d-table__cell --controls key-controls">
        <div class="d-table__cell-actions">
          <DButton
            @action={{this.edit}}
            @label="admin.api_keys.edit"
            @title="admin.api.show_details"
            class="btn-default btn-small"
          />
          <DMenu
            @identifier="api_key-menu"
            @title={{i18n "admin.config_areas.user_fields.more_options.title"}}
            @icon="ellipsis-vertical"
            @onRegisterApi={{this.onRegisterApi}}
            @triggerClass="btn-default"
          >
            <:content>
              <DDropdownMenu as |dropdown|>
                {{#if @apiKey.revoked_at}}
                  <dropdown.item>
                    <DButton
                      @action={{fn this.undoRevokeKey @apiKey}}
                      @icon="arrow-rotate-left"
                      @label="admin.api_keys.undo_revoke"
                      @title="admin.api.undo_revoke"
                    />
                  </dropdown.item>
                {{else}}
                  <dropdown.item>
                    <DButton
                      @action={{fn this.revokeKey @apiKey}}
                      @icon="xmark"
                      @label="admin.api_keys.revoke"
                      @title="admin.api.revoke"
                      class="btn-danger"
                    />
                  </dropdown.item>
                {{/if}}
              </DDropdownMenu>
            </:content>
          </DMenu>
        </div>
      </td>
    </tr>
  </template>
}
