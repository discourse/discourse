import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { fmt } from "discourse/lib/computed";
import Permalink from "admin/models/permalink";

export default Component.extend({
  classNames: ["permalink-form"],
  formSubmitted: false,
  permalinkType: "topic_id",
  permalinkTypePlaceholder: fmt("permalinkType", "admin.permalink.%@"),

  @discourseComputed
  permalinkTypes() {
    return [
      { id: "topic_id", name: I18n.t("admin.permalink.topic_id") },
      { id: "post_id", name: I18n.t("admin.permalink.post_id") },
      { id: "category_id", name: I18n.t("admin.permalink.category_id") },
      { id: "external_url", name: I18n.t("admin.permalink.external_url") }
    ];
  },

  didInsertElement() {
    this._super(...arguments);

    schedule("afterRender", () => {
      $(this.element.querySelector(".external-url")).keydown(e => {
        // enter key
        if (e.keyCode === 13) {
          this.send("submit");
        }
      });
    });
  },

  focusPermalink() {
    schedule("afterRender", () =>
      this.element.querySelector(".permalink-url").focus()
    );
  },

  actions: {
    submit() {
      if (!this.formSubmitted) {
        this.set("formSubmitted", true);

        Permalink.create({
          url: this.url,
          permalink_type: this.permalinkType,
          permalink_type_value: this.permalink_type_value
        })
          .save()
          .then(
            result => {
              this.setProperties({
                url: "",
                permalink_type_value: "",
                formSubmitted: false
              });

              this.action(Permalink.create(result.permalink));

              this.focusPermalink();
            },
            e => {
              this.set("formSubmitted", false);

              let error;
              if (e.responseJSON && e.responseJSON.errors) {
                error = I18n.t("generic_error_with_reason", {
                  error: e.responseJSON.errors.join(". ")
                });
              } else {
                error = I18n.t("generic_error");
              }
              bootbox.alert(error, () => this.focusPermalink());
            }
          );
      }
    },

    onChangePermalinkType(type) {
      this.set("permalinkType", type);
    }
  }
});
