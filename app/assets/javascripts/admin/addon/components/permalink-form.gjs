import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import TextField from "discourse/components/text-field";
import { fmt } from "discourse/lib/computed";
import discourseComputed, { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import Permalink from "admin/models/permalink";
import ComboBox from "select-kit/components/combo-box";

@tagName("")
export default class PermalinkForm extends Component {
  @service dialog;

  formSubmitted = false;
  permalinkType = "topic_id";

  @fmt("permalinkType", "admin.permalink.%@") permalinkTypePlaceholder;

  action = null;
  permalinkTypeValue = null;

  @discourseComputed
  permalinkTypes() {
    return [
      { id: "topic_id", name: i18n("admin.permalink.topic_id") },
      { id: "post_id", name: i18n("admin.permalink.post_id") },
      { id: "category_id", name: i18n("admin.permalink.category_id") },
      { id: "tag_name", name: i18n("admin.permalink.tag_name") },
      { id: "external_url", name: i18n("admin.permalink.external_url") },
      { id: "user_id", name: i18n("admin.permalink.user_id") },
    ];
  }

  @bind
  focusPermalink() {
    schedule("afterRender", () =>
      document.querySelector(".permalink-url")?.focus()
    );
  }

  @action
  submitFormOnEnter(event) {
    if (event.key === "Enter") {
      this.onSubmit();
    }
  }

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
              error = i18n("generic_error_with_reason", {
                error: e.jqXHR.responseJSON.errors.join(". "),
              });
            } else {
              error = i18n("generic_error");
            }

            this.dialog.alert({
              message: error,
              didConfirm: () => this.focusPermalink(),
              didCancel: () => this.focusPermalink(),
            });
          }
        );
    }
  }

  <template>
    <div class="permalink-form">
      <div class="inline-form">
        <label>{{i18n "admin.permalink.form.label"}}</label>

        <TextField
          @value={{this.url}}
          @disabled={{this.formSubmitted}}
          @placeholderKey="admin.permalink.url"
          @autocorrect="off"
          @autocapitalize="off"
          class="permalink-url"
        />

        <ComboBox
          @content={{this.permalinkTypes}}
          @value={{this.permalinkType}}
          @onChange={{fn (mut this.permalinkType)}}
          class="permalink-type"
        />

        <TextField
          @value={{this.permalinkTypeValue}}
          @disabled={{this.formSubmitted}}
          @placeholderKey={{this.permalinkTypePlaceholder}}
          @autocorrect="off"
          @autocapitalize="off"
          @keyDown={{this.submitFormOnEnter}}
          class="permalink-destination"
        />

        <DButton
          @action={{this.onSubmit}}
          @disabled={{this.formSubmitted}}
          @label="admin.permalink.form.add"
          class="permalink-add"
        />
      </div>
    </div>
  </template>
}
