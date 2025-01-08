import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DropdownMenu from "discourse/components/dropdown-menu";
import avatar from "discourse/helpers/avatar";
import formatDate from "discourse/helpers/format-date";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import DMenu from "float-kit/components/d-menu";

export default class ApiKeysList extends Component {
  @service router;

  @tracked apiKey = this.args.apiKey;

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
    <tr class="d-admin-row__content">
      <td class="d-admin-row__overview key">
        {{this.apiKey.truncatedKey}}
        {{#if this.apiKey.revoked_at}}
          <span class="d-admin-table__badge">{{i18n
              "admin.api.revoked"
            }}</span>{{/if}}
      </td>
      <td class="d-admin-row__detail key-description">
        <div class="d-admin-row__mobile-label">{{i18n
            "admin.api.description"
          }}</div>
        {{this.apiKey.shortDescription}}
      </td>
      <td class="d-admin-row__detail key-user">
        <div class="d-admin-row__mobile-label">{{i18n "admin.api.user"}}</div>
        {{#if this.apiKey.user}}
          <LinkTo @route="adminUser" @model={{this.apiKey.user}}>
            {{avatar this.apiKey.user imageSize="small"}}
          </LinkTo>
        {{else}}
          {{i18n "admin.api.all_users"}}
        {{/if}}
      </td>
      <td class="d-admin-row__detail key-created">
        <LinkTo @route="adminUser" @model={{this.apiKey.createdBy}}>
          {{avatar this.apiKey.createdBy imageSize="small"}}
        </LinkTo>
        <div class="d-admin-row__mobile-label">{{i18n
            "admin.api.created"
          }}</div>
        {{formatDate this.apiKey.created_at}}
      </td>
      <td class="d-admin-row__detail key-last-used">
        <div class="d-admin-row__mobile-label">{{i18n
            "admin.api.last_used"
          }}</div>
        {{#if this.apiKey.last_used_at}}
          {{formatDate this.apiKey.last_used_at}}
        {{else}}
          {{i18n "admin.api.never_used"}}
        {{/if}}
      </td>
      <td class="d-admin-row__controls key-controls">
        <div class="d-admin-row__controls-options">
          <DButton
            @action={{this.edit}}
            @label="admin.api_keys.edit"
            @title="admin.api.show_details"
            class="btn-small"
          />
          <DMenu
            @identifier="api_key-menu"
            @title={{i18n "admin.config_areas.user_fields.more_options.title"}}
            @icon="ellipsis-vertical"
            @onRegisterApi={{this.onRegisterApi}}
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
