import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import iconOrImage from "discourse/helpers/icon-or-image";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import AdminBadgesList from "admin/components/admin-badges-list";

export default class AdminBadgesAward extends Component {
  @service adminBadges;
  @service dialog;

  @tracked saving = false;
  @tracked replaceBadgeOwners = false;
  @tracked grantExistingHolders = false;
  @tracked fileSelected = false;
  @tracked unmatchedEntries = null;
  @tracked resultsMessage = null;
  @tracked success = false;
  @tracked unmatchedEntriesCount = 0;

  get badges() {
    return this.adminBadges.badges;
  }

  resetState() {
    this.saving = false;
    this.unmatchedEntries = null;
    this.resultsMessage = null;
    this.success = false;
    this.unmatchedEntriesCount = 0;

    this.updateFileSelected();
  }

  get massAwardButtonDisabled() {
    return !this.fileSelected || this.saving;
  }

  get unmatchedEntriesTruncated() {
    let count = this.unmatchedEntriesCount;
    let length = this.unmatchedEntries.length;
    return count && length && count > length;
  }

  @action
  updateFileSelected() {
    this.fileSelected = !!document.querySelector("#massAwardCSVUpload")?.files
      ?.length;
  }

  @action
  massAward() {
    const file = document.querySelector("#massAwardCSVUpload").files[0];

    if (this.args.badge && file) {
      const options = {
        type: "POST",
        processData: false,
        contentType: false,
        data: new FormData(),
      };

      options.data.append("file", file);
      options.data.append("replace_badge_owners", this.replaceBadgeOwners);
      options.data.append("grant_existing_holders", this.grantExistingHolders);

      this.resetState();
      this.saving = true;

      ajax(`/admin/badges/award/${this.args.badge.id}`, options)
        .then(
          ({
            matched_users_count: matchedCount,
            unmatched_entries: unmatchedEntries,
            unmatched_entries_count: unmatchedEntriesCount,
          }) => {
            this.resultsMessage = i18n("admin.badges.mass_award.success", {
              count: matchedCount,
            });
            this.success = true;
            if (unmatchedEntries.length) {
              this.unmatchedEntries = unmatchedEntries;
              this.unmatchedEntriesCount = unmatchedEntriesCount;
            }
          }
        )
        .catch((error) => {
          this.resultsMessage = extractError(error);
          this.success = false;
        })
        .finally(() => (this.saving = false));
    } else {
      this.dialog.alert(i18n("admin.badges.mass_award.aborted"));
    }
  }

  <template>
    <AdminBadgesList @badges={{this.badges}} />
    <section class="current-badge content-body">
      <h2>{{i18n "admin.badges.mass_award.title"}}</h2>
      <p>{{i18n "admin.badges.mass_award.description"}}</p>

      {{#if @badge}}
        <form class="form-horizontal">
          <div class="badge-preview control-group">
            {{iconOrImage @badge}}
            <span class="badge-display-name">{{@badge.name}}</span>
          </div>
          <div class="control-group">
            <h4>{{i18n "admin.badges.mass_award.upload_csv"}}</h4>
            <input
              type="file"
              id="massAwardCSVUpload"
              accept=".csv"
              onchange={{this.updateFileSelected}}
            />
          </div>
          <div class="control-group">
            <label class="checkbox-label">
              <Input @type="checkbox" @checked={{this.replaceBadgeOwners}} />
              {{i18n "admin.badges.mass_award.replace_owners"}}
            </label>
            {{#if @badge.multiple_grant}}
              <label class="grant-existing-holders">
                <Input
                  @type="checkbox"
                  @checked={{this.grantExistingHolders}}
                  class="grant-existing-holders-checkbox"
                />
                {{i18n "admin.badges.mass_award.grant_existing_holders"}}
              </label>
            {{/if}}
          </div>
          <DButton
            @action={{this.massAward}}
            @disabled={{this.massAwardButtonDisabled}}
            @icon="certificate"
            @label="admin.badges.mass_award.perform"
            type="submit"
            class="btn-primary"
          />
          <LinkTo @route="adminBadges.index" class="btn btn-normal">
            {{icon "xmark"}}
            <span>{{i18n "cancel"}}</span>
          </LinkTo>
        </form>
        {{#if this.saving}}
          {{i18n "uploading"}}
        {{/if}}
        {{#if this.resultsMessage}}
          <p>
            {{#if this.success}}
              {{icon "check" class="bulk-award-status-icon success"}}
            {{else}}
              {{icon "xmark" class="bulk-award-status-icon failure"}}
            {{/if}}
            {{this.resultsMessage}}
          </p>
          {{#if this.unmatchedEntries.length}}
            <p>
              {{icon
                "triangle-exclamation"
                class="bulk-award-status-icon failure"
              }}
              <span>
                {{#if this.unmatchedEntriesTruncated}}
                  {{i18n
                    "admin.badges.mass_award.csv_has_unmatched_users_truncated_list"
                    count=this.unmatchedEntriesCount
                  }}
                {{else}}
                  {{i18n "admin.badges.mass_award.csv_has_unmatched_users"}}
                {{/if}}
              </span>
            </p>
            <ul>
              {{#each this.unmatchedEntries as |entry|}}
                <li>{{entry}}</li>
              {{/each}}
            </ul>
          {{/if}}
        {{/if}}
      {{else}}
        <span class="badge-required">{{i18n
            "admin.badges.mass_award.no_badge_selected"
          }}</span>
      {{/if}}
    </section>
  </template>
}
