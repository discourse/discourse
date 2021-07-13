import Controller from "@ember/controller";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import bootbox from "bootbox";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { escapeExpression } from "discourse/lib/utilities";

export default Controller.extend({
  saving: false,
  replaceBadgeOwners: false,
  grantExistingHolders: false,

  actions: {
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
        options.data.append(
          "grant_existing_holders",
          this.grantExistingHolders
        );

        this.set("saving", true);

        ajax(`/admin/badges/award/${this.model.id}`, options)
          .then(
            ({
              matched_users_count: matchedCount,
              unmatched_entries: unmatchedEntries,
            }) => {
              if (unmatchedEntries.length) {
                const entriesToList = unmatchedEntries
                  .map((entry) => `<li>${escapeExpression(entry)}</li>`)
                  .join("");
                bootbox.alert(
                  I18n.t(
                    "admin.badges.mass_award.success_with_unmatched_entries",
                    { count: matchedCount, users: `<ul>${entriesToList}</ul>` }
                  )
                );
              } else {
                bootbox.alert(
                  I18n.t("admin.badges.mass_award.success", {
                    count: matchedCount,
                  })
                );
              }
            }
          )
          .catch(popupAjaxError)
          .finally(() => this.set("saving", false));
      } else {
        bootbox.alert(I18n.t("admin.badges.mass_award.aborted"));
      }
    },
  },
});
