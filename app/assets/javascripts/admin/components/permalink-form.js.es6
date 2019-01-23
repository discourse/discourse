import { default as computed } from "ember-addons/ember-computed-decorators";
import { fmt } from "discourse/lib/computed";
import Permalink from "admin/models/permalink";

export default Ember.Component.extend({
  classNames: ["permalink-form"],
  formSubmitted: false,
  permalinkType: "topic_id",
  permalinkTypePlaceholder: fmt("permalinkType", "admin.permalink.%@"),

  @computed
  permalinkTypes() {
    return [
      { id: "topic_id", name: I18n.t("admin.permalink.topic_id") },
      { id: "post_id", name: I18n.t("admin.permalink.post_id") },
      { id: "category_id", name: I18n.t("admin.permalink.category_id") },
      { id: "external_url", name: I18n.t("admin.permalink.external_url") }
    ];
  },

  focusPermalink() {
    Ember.run.schedule("afterRender", () => this.$(".permalink-url").focus());
  },

  actions: {
    submit() {
      if (!this.get("formSubmitted")) {
        this.set("formSubmitted", true);

        Permalink.create({
          url: this.get("url"),
          permalink_type: this.get("permalinkType"),
          permalink_type_value: this.get("permalink_type_value")
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
    }
  },

  didInsertElement() {
    this._super(...arguments);

    Ember.run.schedule("afterRender", () => {
      this.$(".external-url").keydown(e => {
        // enter key
        if (e.keyCode === 13) {
          this.send("submit");
        }
      });
    });
  }
});
