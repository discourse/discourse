import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import avatar from "discourse/helpers/avatar";
import icon from "discourse/helpers/d-icon";
import formatDate from "discourse/helpers/format-date";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

const SCOPE_ICONS = {
  global: "globe",
  read_only: "eye",
  granular: "bullseye",
};

export default class ApiKeyItem extends Component {
  @service router;

  @tracked apiKey = this.args.apiKey;

  get scopeIcon() {
    return SCOPE_ICONS[this.apiKey.scope_mode];
  }

  get scopeName() {
    return i18n(`admin.api.scopes.${this.apiKey.scope_mode}`);
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
    this.router.transitionTo("adminApiKeys.show", this.apiKey);
  }

  <template>
    <tr class="d-table__row">
      <td class="d-table__cell --overview key">
        <div class="d-table__value-wrapper">
          {{this.apiKey.truncatedKey}}
          {{#if this.apiKey.revoked_at}}
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
        {{this.apiKey.shortDescription}}
      </td>
      <td class="d-table__cell --detail key-user">
        <div class="d-table__mobile-label">{{i18n "admin.api.user"}}</div>
        {{#if this.apiKey.user}}
          <LinkTo @route="adminUser" @model={{this.apiKey.user}}>
            {{avatar this.apiKey.user imageSize="small"}}
          </LinkTo>
        {{else}}
          {{i18n "admin.api.all_users"}}
        {{/if}}
      </td>
      <td class="d-table__cell --detail key-created">
        <div class="d-table__mobile-label">{{i18n "admin.api.created"}}</div>
        <div class="d-table__value-wrapper">
          <LinkTo @route="adminUser" @model={{this.apiKey.createdBy}}>
            {{avatar this.apiKey.createdBy imageSize="small"}}
          </LinkTo>
          {{formatDate this.apiKey.created_at}}
        </div>
      </td>
      <td class="d-table__cell --detail key-scope">
        <div class="d-table__mobile-label">{{i18n "admin.api.scope"}}</div>
        <div class="d-table__value-wrapper">
          {{icon this.scopeIcon}}
          {{this.scopeName}}
        </div>
      </td>
      <td class="d-table__cell --detail key-last-used">
        <div class="d-table__mobile-label">{{i18n "admin.api.last_used"}}</div>
        {{#if this.apiKey.last_used_at}}
          {{formatDate this.apiKey.last_used_at}}
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
            @class="btn-default"
          >
            <:content>
              <DropdownMenu as |dropdown|>
                {{#if this.apiKey.revoked_at}}
                  <dropdown.item>
                    <DButton
                      @action={{fn this.undoRevokeKey this.apiKey}}
                      @icon="arrow-rotate-left"
                      @label="admin.api_keys.undo_revoke"
                      @title="admin.api.undo_revoke"
                    />
                  </dropdown.item>
                {{else}}
                  <dropdown.item>
                    <DButton
                      @action={{fn this.revokeKey this.apiKey}}
                      @icon="xmark"
                      @label="admin.api_keys.revoke"
                      @title="admin.api.revoke"
                      class="btn-danger"
                    />
                  </dropdown.item>
                {{/if}}
              </DropdownMenu>
            </:content>
          </DMenu>
        </div>
      </td>
    </tr>
  </template>
}
