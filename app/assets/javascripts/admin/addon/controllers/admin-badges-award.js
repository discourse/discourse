import Controller from "@ember/controller";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import { extractError } from "discourse/lib/ajax-error";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  saving: false,
  replaceBadgeOwners: false,
  grantExistingHolders: false,
  fileSelected: false,
  unmatchedEntries: null,
  resultsMessage: null,
  success: false,
  unmatchedEntriesCount: 0,

  resetState() {
    this.setProperties({
      saving: false,
      unmatchedEntries: null,
      resultsMessage: null,
      success: false,
      unmatchedEntriesCount: 0,
    });
    this.send("updateFileSelected");
  },

  @discourseComputed("fileSelected", "saving")
  massAwardButtonDisabled(fileSelected, saving) {
    return !fileSelected || saving;
  },

  @discourseComputed("unmatchedEntriesCount", "unmatchedEntries.length")
  unmatchedEntriesTruncated(unmatchedEntriesCount, length) {
    return unmatchedEntriesCount && length && unmatchedEntriesCount > length;
  },

  @action
  updateFileSelected() {
    this.set(
      "fileSelected",
      !!document.querySelector("#massAwardCSVUpload")?.files?.length
    );
  },

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
      this.set("saving", true);

      ajax(`/admin/badges/award/${this.model.id}`, options)
        .then(
          ({
            matched_users_count: matchedCount,
            unmatched_entries: unmatchedEntries,
            unmatched_entries_count: unmatchedEntriesCount,
          }) => {
            this.setProperties({
              resultsMessage: I18n.t("admin.badges.mass_award.success", {
                count: matchedCount,
              }),
              success: true,
            });
            if (unmatchedEntries.length) {
              this.setProperties({
                unmatchedEntries,
                unmatchedEntriesCount,
              });
            }
          }
        )
        .catch((error) => {
          this.setProperties({
            resultsMessage: extractError(error),
            success: false,
          });
        })
        .finally(() => this.set("saving", false));
    } else {
      bootbox.alert(I18n.t("admin.badges.mass_award.aborted"));
    }
  },
});
