import Component from "@glimmer/component";
import { Input } from "@ember/component";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import iconOrImage from "discourse/helpers/icon-or-image";
import { i18n } from "discourse-i18n";

export default class AdminBadgesAward extends Component {
  @service adminBadges;

  get badges() {
    return this.adminBadges.badges;
  }

  get selectedBadge() {
    if(this.args.badgeId === "new") {
      return;
    }

    return this.badges.findBy("id", this.args.badgeId);
  }

  <template>
    <section class="current-badge content-body">
      <h2>{{i18n "admin.badges.mass_award.title"}}</h2>
      <p>{{i18n "admin.badges.mass_award.description"}}</p>

      {{#if this.selectedBadge}}
        <form class="form-horizontal">
          <div class="badge-preview control-group">
            {{iconOrImage this.selectedBadge}}
            <span class="badge-display-name">{{this.selectedBadge.name}}</span>
          </div>
          <div class="control-group">
            <h4>{{i18n "admin.badges.mass_award.upload_csv"}}</h4>
            <input
              type="file"
              id="massAwardCSVUpload"
              accept=".csv"
              onchange={{@controller.updateFileSelected}}
            />
          </div>
          <div class="control-group">
            <label class="checkbox-label">
              <Input
                @type="checkbox"
                @checked={{@controller.replaceBadgeOwners}}
              />
              {{i18n "admin.badges.mass_award.replace_owners"}}
            </label>
            {{#if this.selectedBadge.multiple_grant}}
              <label class="grant-existing-holders">
                <Input
                  @type="checkbox"
                  @checked={{@controller.grantExistingHolders}}
                  class="grant-existing-holders-checkbox"
                />
                {{i18n "admin.badges.mass_award.grant_existing_holders"}}
              </label>
            {{/if}}
          </div>
          <DButton
            @action={{@controller.massAward}}
            @disabled={{@controller.massAwardButtonDisabled}}
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
        {{#if @controller.saving}}
          {{i18n "uploading"}}
        {{/if}}
        {{#if @controller.resultsMessage}}
          <p>
            {{#if @controller.success}}
              {{icon "check" class="bulk-award-status-icon success"}}
            {{else}}
              {{icon "xmark" class="bulk-award-status-icon failure"}}
            {{/if}}
            {{@controller.resultsMessage}}
          </p>
          {{#if @controller.unmatchedEntries.length}}
            <p>
              {{icon
                "triangle-exclamation"
                class="bulk-award-status-icon failure"
              }}
              <span>
                {{#if @controller.unmatchedEntriesTruncated}}
                  {{i18n
                    "admin.badges.mass_award.csv_has_unmatched_users_truncated_list"
                    count=@controller.unmatchedEntriesCount
                  }}
                {{else}}
                  {{i18n "admin.badges.mass_award.csv_has_unmatched_users"}}
                {{/if}}
              </span>
            </p>
            <ul>
              {{#each @controller.unmatchedEntries as |entry|}}
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
