import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, get } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import DButton from "discourse/components/d-button";
import avatar from "discourse/helpers/avatar";
import formatDate from "discourse/helpers/format-date";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminFormRow from "admin/components/admin-form-row";
import ApiKeyUrlsModal from "admin/components/modal/api-key-urls";
import DTooltip from "float-kit/components/d-tooltip";

export default class AdminConfigAreasApiKeysShow extends Component {
  @service modal;
  @service router;

  @tracked editingDescription = false;
  @tracked scopes = this.args.apiKey.api_key_scopes;
  newDescription = "";

  @action
  async revokeKey(key) {
    try {
      await key.revoke();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async undoRevokeKey(key) {
    try {
      await key.undoRevoke();
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async deleteKey(key) {
    try {
      await key.destroyRecord();
      this.router.transitionTo("adminApiKeys.index");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  async showURLs(urls) {
    await this.modal.show(ApiKeyUrlsModal, {
      model: { urls },
    });
  }

  @action
  toggleEditDescription() {
    this.editingDescription = !this.editingDescription;
    this.newDescription = this.args.apiKey.description;
  }

  @action
  async saveDescription() {
    try {
      await this.args.apiKey.save({ description: this.newDescription });
      this.editingDescription = false;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  setNewDescription(event) {
    this.newDescription = event.currentTarget.value;
  }

  <template>
    <BackButton @route="adminApiKeys.index" @label="admin.api_keys.back" />

    <div class="api-key api-key-show">
      <AdminFormRow @label="admin.api.key">
        {{@apiKey.truncatedKey}}
      </AdminFormRow>

      <AdminFormRow @label="admin.api.description">
        {{#if this.editingDescription}}
          <Input
            @value={{@apiKey.description}}
            {{on "input" this.setNewDescription}}
            name="description"
            maxlength="255"
            placeholder={{i18n "admin.api.description_placeholder"}}
          />
        {{else}}
          <span>
            {{if
              @apiKey.description
              @apiKey.description
              (i18n "admin.api.no_description")
            }}
          </span>
        {{/if}}

        <div class="controls">
          {{#if this.editingDescription}}
            <DButton
              @action={{this.saveDescription}}
              @label="admin.api_keys.save"
            />
            <DButton
              @action={{this.toggleEditDescription}}
              @label="admin.api_keys.cancel"
            />
          {{else}}
            <DButton
              @action={{this.toggleEditDescription}}
              @label="admin.api_keys.edit"
              class="btn-default"
            />
          {{/if}}
        </div>
      </AdminFormRow>

      <AdminFormRow @label="admin.api.user">
        {{#if @apiKey.user}}
          <LinkTo @route="adminUser" @model={{@apiKey.user}}>
            {{avatar @apiKey.user imageSize="small"}}
            {{@apiKey.user.username}}
          </LinkTo>
        {{else}}
          {{i18n "admin.api.all_users"}}
        {{/if}}
      </AdminFormRow>

      <AdminFormRow @label="admin.api.created">
        {{formatDate @apiKey.created_at leaveAgo="true"}}
      </AdminFormRow>

      <AdminFormRow @label="admin.api.updated">
        {{formatDate @apiKey.updated_at leaveAgo="true"}}
      </AdminFormRow>

      <AdminFormRow @label="admin.api.last_used">
        {{#if @apiKey.last_used_at}}
          {{formatDate @apiKey.last_used_at leaveAgo="true"}}
        {{else}}
          {{i18n "admin.api.never_used"}}
        {{/if}}
      </AdminFormRow>

      <AdminFormRow @label="admin.api.revoked">
        {{#if @apiKey.revoked_at}}
          {{formatDate @apiKey.revoked_at leaveAgo="true"}}
        {{else}}
          <span>{{i18n "no_value"}}</span>
        {{/if}}
        <div class="controls">
          {{#if @apiKey.revoked_at}}
            <DButton
              @action={{fn this.undoRevokeKey @apiKey}}
              @label="admin.api.undo_revoke"
            />
            <DButton
              @action={{fn this.deleteKey @apiKey}}
              @label="admin.api.delete"
              class="btn-danger"
            />
          {{else}}
            <DButton
              @action={{fn this.revokeKey @apiKey}}
              @label="admin.api.revoke"
              class="btn-danger"
            />
          {{/if}}
        </div>
      </AdminFormRow>

      {{#if @apiKey.api_key_scopes.length}}
        <h2 class="scopes-title">{{i18n "admin.api.scopes.title"}}</h2>

        <table class="scopes-table grid">
          <thead>
            <tr>
              <td>{{i18n "admin.api.scopes.resource"}}</td>
              <td>{{i18n "admin.api.scopes.action"}}</td>
              <td>{{i18n "admin.api.scopes.allowed_urls"}}</td>
              <td>{{i18n "admin.api.scopes.allowed_parameters"}}</td>
            </tr>
          </thead>
          <tbody>
            {{#each @apiKey.api_key_scopes as |scope|}}
              <tr>
                <td>{{scope.resource}}</td>
                <td>
                  {{scope.action}}
                  <DTooltip
                    @icon="circle-question"
                    @content={{i18n
                      (concat
                        "admin.api.scopes.descriptions."
                        scope.resource
                        "."
                        scope.key
                      )
                    }}
                    class="scope-tooltip"
                  />
                </td>
                <td>
                  <DButton
                    @icon="link"
                    @action={{fn this.showURLs scope.urls}}
                    class="btn-info"
                  />
                </td>
                <td>
                  {{#each scope.parameters as |p|}}
                    <div>
                      <b>{{p}}:</b>
                      {{#if (get scope.allowed_parameters p)}}
                        {{get scope.allowed_parameters p}}
                      {{else}}
                        {{i18n "admin.api.scopes.any_parameter"}}
                      {{/if}}
                    </div>
                  {{/each}}
                </td>
              </tr>
            {{/each}}
          </tbody>
        </table>
      {{/if}}
    </div>
  </template>
}
