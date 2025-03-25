<section class="current-badge content-body">
  <h2>{{i18n "admin.badges.mass_award.title"}}</h2>
  <p>{{i18n "admin.badges.mass_award.description"}}</p>

  {{#if this.model}}
    <form class="form-horizontal">
      <div class="badge-preview control-group">
        {{#if this.model}}
          {{icon-or-image this.model}}
          <span class="badge-display-name">{{this.model.name}}</span>
        {{else}}
          <span class="badge-placeholder">{{i18n
              "admin.badges.mass_award.no_badge_selected"
            }}</span>
        {{/if}}
      </div>
      <div class="control-group">
        <h4>{{i18n "admin.badges.mass_award.upload_csv"}}</h4>
        <input
          type="file"
          id="massAwardCSVUpload"
          accept=".csv"
          onchange={{action "updateFileSelected"}}
        />
      </div>
      <div class="control-group">
        <label class="checkbox-label">
          <Input @type="checkbox" @checked={{this.replaceBadgeOwners}} />
          {{i18n "admin.badges.mass_award.replace_owners"}}
        </label>
        {{#if this.model.multiple_grant}}
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
        {{d-icon "xmark"}}
        <span>{{i18n "cancel"}}</span>
      </LinkTo>
    </form>
    {{#if this.saving}}
      {{i18n "uploading"}}
    {{/if}}
    {{#if this.resultsMessage}}
      <p>
        {{#if this.success}}
          {{d-icon "check" class="bulk-award-status-icon success"}}
        {{else}}
          {{d-icon "xmark" class="bulk-award-status-icon failure"}}
        {{/if}}
        {{this.resultsMessage}}
      </p>
      {{#if this.unmatchedEntries.length}}
        <p>
          {{d-icon
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