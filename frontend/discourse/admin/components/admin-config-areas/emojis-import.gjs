import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import BackButton from "discourse/components/back-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const CONFLICT_CATEGORIES = [
  "conflict_both",
  "conflict_image",
  "conflict_group",
];

const ImportRowControls = <template>
  {{#if (eq @category "invalid")}}
    {{#if @row.errors}}
      <p class="admin-emoji-import__error">{{get @row.errors 0}}</p>
    {{/if}}
  {{else if (eq @row.category "identical")}}
    <span class="admin-emoji-import__badge --skip">
      {{i18n "admin.emoji.import_will_skip"}}
    </span>
  {{else if (eq @category "conflict")}}
    <div class="admin-emoji-import__conflict-resolution">
      <label>
        <input
          type="radio"
          name={{concat "resolution-" @row.name}}
          value="incoming"
          checked={{eq (or (get @resolutions @row.name) "incoming") "incoming"}}
          {{on "change" (fn @onSetResolution @row.name "incoming")}}
        />
        {{i18n "admin.emoji.import_use_incoming"}}
      </label>
      <label>
        <input
          type="radio"
          name={{concat "resolution-" @row.name}}
          value="keep"
          checked={{eq (get @resolutions @row.name) "keep"}}
          {{on "change" (fn @onSetResolution @row.name "keep")}}
        />
        {{i18n "admin.emoji.import_keep_existing"}}
      </label>
    </div>
  {{/if}}
</template>;

const ImportSection = <template>
  <div class="admin-emoji-import__section">
    <h3 class="admin-emoji-import__section-heading">
      {{#if (eq @category "no_action")}}
        {{i18n "admin.emoji.import_category.new"}}
        <span class="admin-emoji-import__section-count">({{@newCount}})</span>
        {{#if @identicalCount}}
          <small class="admin-emoji-import__section-subtitle">
            {{i18n "admin.emoji.import_unchanged_count" count=@identicalCount}}
          </small>
        {{/if}}
      {{else}}
        {{i18n (concat "admin.emoji.import_category." @category)}}
        <span
          class="admin-emoji-import__section-count"
        >({{@rows.length}})</span>
      {{/if}}
    </h3>
    {{#if (eq @category "invalid")}}
      <p class="admin-emoji-import__section-description">
        {{i18n "admin.emoji.import_excluded"}}
      </p>
    {{/if}}
    <table class="d-table admin-emoji-import__table">
      <thead class="d-table__header">
        <tr class="d-table__row">
          <th class="d-table__header-cell">{{i18n "admin.emoji.image"}}</th>
          <th class="d-table__header-cell">{{i18n "admin.emoji.name"}}</th>
          <th class="d-table__header-cell">{{i18n "admin.emoji.group"}}</th>
          <th class="d-table__header-cell"></th>
        </tr>
      </thead>
      <tbody class="d-table__body">
        {{#each @rows as |row|}}
          <tr class="d-table__row">
            <td class="d-table__cell --overview">
              {{#if row.incoming_url}}
                <img
                  class="emoji emoji-custom"
                  src={{row.incoming_url}}
                  alt={{i18n "admin.emoji.import_incoming_alt" name=row.name}}
                />
              {{/if}}
              {{#if (eq @category "conflict")}}
                {{#if row.existing_url}}
                  <span
                    class="admin-emoji-import__existing-value"
                    aria-label={{i18n
                      "admin.emoji.import_existing_alt"
                      name=row.name
                    }}
                  >
                    <img
                      class="emoji emoji-custom"
                      src={{row.existing_url}}
                      alt=""
                      aria-hidden="true"
                    />
                  </span>
                {{/if}}
              {{/if}}
            </td>
            <td class="d-table__cell --detail">
              :{{row.name}}:
              {{#if (eq @category "conflict")}}
                <span class="admin-emoji-import__existing-value">
                  :{{row.name}}:
                </span>
              {{/if}}
            </td>
            <td class="d-table__cell --detail">
              {{row.group}}
              {{#if (eq @category "conflict")}}
                <span
                  class="admin-emoji-import__existing-value"
                  aria-label={{i18n "admin.emoji.import_existing_group_alt"}}
                >
                  {{row.existing_group}}
                </span>
              {{/if}}
            </td>
            <td class="d-table__cell --controls">
              <ImportRowControls
                @category={{@category}}
                @row={{row}}
                @resolutions={{@resolutions}}
                @onSetResolution={{@onSetResolution}}
              />
            </td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </div>
</template>;

export default class AdminConfigAreasEmojisImport extends Component {
  @service router;
  @service adminEmojis;

  @tracked previewToken = null;
  @tracked previewRows = null;
  @tracked resolutions = {};
  @tracked isUploading = false;
  @tracked isConfirming = false;

  get isPreviewPhase() {
    return this.previewRows !== null;
  }

  get rowsByCategory() {
    if (!this.previewRows) {
      return {};
    }
    const grouped = {};
    grouped["invalid"] = this.previewRows.filter(
      (r) => r.category === "invalid"
    );
    grouped["conflict"] = this.previewRows.filter((r) =>
      CONFLICT_CATEGORIES.includes(r.category)
    );
    grouped["no_action"] = this.previewRows.filter(
      (r) => r.category === "new" || r.category === "identical"
    );
    return grouped;
  }

  get summaryCounts() {
    if (!this.previewRows) {
      return null;
    }
    return {
      no_action: this.rowsByCategory["no_action"].length,
      newCount: this.previewRows.filter((r) => r.category === "new").length,
      identicalCount: this.previewRows.filter((r) => r.category === "identical")
        .length,
      conflicts: this.rowsByCategory["conflict"].length,
      invalid: this.rowsByCategory["invalid"].length,
    };
  }

  @action
  async uploadZip(event) {
    const file = event.target.files[0];
    if (!file) {
      return;
    }

    this.isUploading = true;

    const formData = new FormData();
    formData.append("file", file);

    try {
      const data = await ajax("/admin/config/emoji/import_preview", {
        type: "POST",
        data: formData,
        processData: false,
        contentType: false,
      });

      this.previewToken = data.token;
      this.previewRows = data.rows;
      this.resolutions = {};
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.isUploading = false;
      event.target.value = null;
    }
  }

  @action
  setResolution(name, value) {
    this.resolutions = { ...this.resolutions, [name]: value };
  }

  @action
  async confirm() {
    this.isConfirming = true;

    try {
      await ajax("/admin/config/emoji/import_confirm", {
        type: "POST",
        data: { token: this.previewToken, resolutions: this.resolutions },
      });

      await this.adminEmojis.refresh();

      this.router.transitionTo("adminEmojis.index");
    } catch (err) {
      popupAjaxError(err);
    } finally {
      this.isConfirming = false;
    }
  }

  @action
  cancel() {
    this.previewRows = null;
    this.previewToken = null;
    this.resolutions = {};
  }

  <template>
    <BackButton @route="adminEmojis.index" @label="admin.emoji.back" />
    <div class="admin-emoji-import">

      {{#if this.isPreviewPhase}}
        <h2 class="admin-emoji-import__heading">{{i18n
            "admin.emoji.import_preview_heading"
          }}</h2>
        {{#if this.summaryCounts}}
          <p class="admin-emoji-import__summary">
            {{i18n
              "admin.emoji.import_summary"
              new=this.summaryCounts.newCount
              conflicts=this.summaryCounts.conflicts
              unchanged=this.summaryCounts.identicalCount
              invalid=this.summaryCounts.invalid
            }}
          </p>
        {{/if}}

        {{#each-in this.rowsByCategory as |category rows|}}
          {{#if rows.length}}
            <ImportSection
              @category={{category}}
              @rows={{rows}}
              @resolutions={{this.resolutions}}
              @onSetResolution={{this.setResolution}}
              @newCount={{this.summaryCounts.newCount}}
              @identicalCount={{this.summaryCounts.identicalCount}}
            />
          {{/if}}
        {{/each-in}}

        <div class="admin-emoji-import__actions">
          <DButton
            @action={{this.confirm}}
            @label="admin.emoji.import_confirm"
            @disabled={{this.isConfirming}}
            @isLoading={{this.isConfirming}}
            class="btn-primary"
          />
          <DButton
            @action={{this.cancel}}
            @label="cancel"
            class="btn-default"
          />
        </div>

      {{else}}
        <h2 class="admin-emoji-import__heading">{{i18n
            "admin.emoji.import_heading"
          }}</h2>
        <p class="admin-emoji-import__description">
          {{i18n "admin.emoji.import_description"}}
        </p>
        <div class="inputs">
          <input
            type="file"
            accept=".zip"
            class="admin-emoji-import__file-input"
            disabled={{this.isUploading}}
            {{on "change" this.uploadZip}}
          />
          {{#if this.isUploading}}
            <span>{{i18n "admin.emoji.uploading"}}</span>
          {{/if}}
        </div>
      {{/if}}

    </div>
  </template>
}
