import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminBadgesAwardController extends Controller {
  @service dialog;
  @tracked saving = false;
  @tracked replaceBadgeOwners = false;
  @tracked grantExistingHolders = false;
  @tracked fileSelected = false;
  @tracked unmatchedEntries = null;
  @tracked resultsMessage = null;
  @tracked success = false;
  @tracked unmatchedEntriesCount = 0;

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

    if (this.model && file) {
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

      ajax(`/admin/badges/award/${this.model.id}`, options)
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
}
