import Component from "@ember/component";
import I18n from "I18n";
import Permalink from "admin/models/permalink";
import bootbox from "bootbox";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { fmt } from "discourse/lib/computed";
import { schedule } from "@ember/runloop";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",
  formSubmitted: false,
  permalinkType: "topic_id",
  permalinkTypePlaceholder: fmt("permalinkType", "admin.permalink.%@"),
  action: null,
  permalinkTypeValue: null,

  @discourseComputed
  permalinkTypes() {
    return [
      { id: "topic_id", name: I18n.t("admin.permalink.topic_id") },
      { id: "post_id", name: I18n.t("admin.permalink.post_id") },
      { id: "category_id", name: I18n.t("admin.permalink.category_id") },
      { id: "tag_name", name: I18n.t("admin.permalink.tag_name") },
      { id: "external_url", name: I18n.t("admin.permalink.external_url") },
    ];
  },

  @bind
  focusPermalink() {
    schedule("afterRender", () =>
      this.element.querySelector(".permalink-url")?.focus()
    );
  },

  @action
  submitFormOnEnter(event) {
    if (event.key === "Enter") {
      this.submit();
    }
  },

  @action
  onSubmit() {
    if (!this.formSubmitted) {
      this.set("formSubmitted", true);

      Permalink.create({
        url: this.url,
        permalink_type: this.permalinkType,
        permalink_type_value: this.permalinkTypeValue,
      })
        .save()
        .then(
          (result) => {
            this.setProperties({
              url: "",
              permalinkTypeValue: "",
              formSubmitted: false,
            });

            this.action(Permalink.create(result.permalink));

            this.focusPermalink();
          },
          (e) => {
            this.set("formSubmitted", false);

            let error;
            if (e?.jqXHR?.responseJSON?.errors) {
              error = I18n.t("generic_error_with_reason", {
                error: e.jqXHR.responseJSON.errors.join(". "),
              });
            } else {
              error = I18n.t("generic_error");
            }
            bootbox.alert(error, this.focusPermalink);
          }
        );
    }
  },
});
