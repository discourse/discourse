import { fn } from "@ember/helper";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import DPageSubheader from "discourse/components/d-page-subheader";
import DropdownMenu from "discourse/components/dropdown-menu";
import icon from "discourse/helpers/d-icon";
import htmlSafe from "discourse/helpers/html-safe";
import routeAction from "discourse/helpers/route-action";
import { i18n } from "discourse-i18n";
import UppyBackupUploader from "admin/components/uppy-backup-uploader";
import humanSize from "admin/helpers/human-size";
import DMenu from "float-kit/components/d-menu";

export default RouteTemplate(
  <template>
    <DPageSubheader @titleLabel={{i18n "admin.backups.files_title"}}>
      <:actions as |actions|>
        <actions.Wrapped as |wrapped|>
          {{#if @controller.siteSettings.enable_backups}}
            {{#if @controller.localBackupStorage}}
              <UppyBackupUploader
                class={{wrapped.buttonClass}}
                @done={{routeAction "uploadSuccess"}}
                @localBackupStorage={{@controller.localBackupStorage}}
              />
            {{else}}
              <UppyBackupUploader
                class={{wrapped.buttonClass}}
                @done={{routeAction "remoteUploadSuccess"}}
              />
            {{/if}}
          {{/if}}
        </actions.Wrapped>
      </:actions>
    </DPageSubheader>

    {{#if @controller.status.restoreDisabled}}
      <div class="backup-message alert alert-info">
        {{icon "circle-info"}}
        {{htmlSafe
          (i18n
            "admin.backups.operations.restore.is_disabled"
            url=@controller.restoreSettingsUrl
          )
        }}
      </div>
    {{/if}}

    <table class="d-admin-table admin-backups-list">
      <thead>
        <th>{{i18n "admin.backups.columns.filename"}}</th>
        <th class="backup-size">{{i18n "admin.backups.columns.size"}}</th>
        <th></th>
      </thead>
      <tbody>
        {{#each @controller.model as |backup|}}
          <tr
            class="d-admin-row__content backup-item-row"
            data-backup-filename={{backup.filename}}
          >
            <td class="d-admin-row__overview">
              <div class="backup-filename">
                {{backup.filename}}
              </div>
            </td>
            <td class="d-admin-row__detail backup-size">
              <div class="d-admin-row__mobile-label">
                {{i18n "admin.backups.columns.size"}}
              </div>
              {{humanSize backup.size}}
            </td>
            <td class="d-admin-row__controls backup-controls">
              <div class="d-admin-row__controls-options">
                <DButton
                  @action={{fn @controller.download backup}}
                  @title="admin.backups.operations.download.title"
                  @label="admin.backups.operations.download.label"
                  class="btn-default btn-small backup-item-row__download"
                />

                {{#if @controller.siteSettings.enable_backups}}
                  <DMenu
                    @identifier="backup-item-menu"
                    @title={{i18n "more_options"}}
                    @icon="ellipsis-vertical"
                    class="btn-default btn-small"
                  >
                    <:content>
                      <DropdownMenu as |dropdown|>
                        <dropdown.item>
                          <DButton
                            @icon="play"
                            @action={{fn (routeAction "startRestore") backup}}
                            @disabled={{@controller.status.restoreDisabled}}
                            @title={{@controller.restoreTitle}}
                            @label="admin.backups.operations.restore.label"
                            class="btn-transparent backup-item-row__restore"
                          />
                        </dropdown.item>
                        <dropdown.item>
                          <DButton
                            @icon="trash-can"
                            @action={{fn (routeAction "destroyBackup") backup}}
                            @disabled={{@controller.status.isOperationRunning}}
                            @title={{@controller.deleteTitle}}
                            @label="admin.backups.operations.destroy.title"
                            class="btn-transparent btn-danger backup-item-row__delete"
                          />
                        </dropdown.item>
                      </DropdownMenu>
                    </:content>
                  </DMenu>
                {{/if}}
              </div>
            </td>
          </tr>
        {{else}}
          <tr>
            <td>{{i18n "admin.backups.none"}}</td>
            <td></td>
            <td></td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </template>
);
