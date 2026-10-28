import { fn } from "@ember/helper";
import { trustHTML } from "@ember/template";
import UppyBackupUploader from "discourse/admin/components/uppy-backup-uploader";
import humanSize from "discourse/admin/helpers/human-size";
import DMenu from "discourse/float-kit/components/d-menu";
import routeAction from "discourse/helpers/route-action";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default <template>
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
      {{dIcon "circle-info"}}
      {{trustHTML
        (i18n
          "admin.backups.operations.restore.is_disabled"
          url=@controller.restoreSettingsUrl
        )
      }}
    </div>
  {{/if}}

  <table class="d-table admin-backups-list">
    <thead class="d-table__header">
      <tr class="d-table__row">
        <th class="d-table__header-cell">{{i18n
            "admin.backups.columns.filename"
          }}</th>
        <th class="backup-size">{{i18n "admin.backups.columns.size"}}</th>
        <th class="d-table__header-cell"></th>
      </tr>
    </thead>
    <tbody class="d-table__body">
      {{#each @controller.model as |backup|}}
        <tr
          class="d-table__row backup-item-row"
          data-backup-filename={{backup.filename}}
        >
          <td class="d-table__cell --overview">
            <div class="backup-filename">
              {{backup.filename}}
            </div>
          </td>
          <td class="d-table__cell --detail backup-size">
            <div class="d-table__mobile-label">
              {{i18n "admin.backups.columns.size"}}
            </div>
            {{humanSize backup.size}}
          </td>
          <td class="d-table__cell --controls backup-controls">
            <div class="d-table__cell-actions">
              <DButton
                class="btn-default btn-small backup-item-row__download"
                @action={{fn @controller.download backup}}
                @label="admin.backups.operations.download.label"
                @title="admin.backups.operations.download.title"
              />

              {{#if @controller.siteSettings.enable_backups}}
                <DMenu
                  class="btn-default btn-small"
                  @icon="ellipsis-vertical"
                  @identifier="backup-item-menu"
                  @title={{i18n "more_options"}}
                >
                  <:content>
                    <DDropdownMenu as |dropdown|>
                      <dropdown.item>
                        <DButton
                          class="btn-transparent backup-item-row__restore"
                          @action={{fn (routeAction "startRestore") backup}}
                          @disabled={{@controller.status.restoreDisabled}}
                          @icon="play"
                          @label="admin.backups.operations.restore.label"
                          @title={{@controller.restoreTitle}}
                        />
                      </dropdown.item>
                      <dropdown.item>
                        <DButton
                          class="btn-transparent --danger backup-item-row__delete"
                          @action={{fn (routeAction "destroyBackup") backup}}
                          @disabled={{@controller.status.isOperationRunning}}
                          @icon="trash-can"
                          @label="admin.backups.operations.destroy.title"
                          @title={{@controller.deleteTitle}}
                        />
                      </dropdown.item>
                    </DDropdownMenu>
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
