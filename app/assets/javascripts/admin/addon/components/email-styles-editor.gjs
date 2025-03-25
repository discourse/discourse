import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action, computed } from "@ember/object";
import { reads } from "@ember/object/computed";
import { service } from "@ember/service";
import AceEditor from "discourse/components/ace-editor";
import DButton from "discourse/components/d-button";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";

export default class EmailStylesEditor extends Component {
  @service dialog;

  @reads("fieldName") editorId;

  @discourseComputed("fieldName")
  currentEditorMode(fieldName) {
    return fieldName === "css" ? "scss" : fieldName;
  }

  @discourseComputed("fieldName", "styles.html", "styles.css")
  resetDisabled(fieldName) {
    return (
      this.get(`styles.${fieldName}`) ===
      this.get(`styles.default_${fieldName}`)
    );
  }

  @computed("styles", "fieldName")
  get editorContents() {
    return this.styles[this.fieldName];
  }

  set editorContents(value) {
    this.styles.setField(this.fieldName, value);
  }

  @action
  reset() {
    this.dialog.yesNoConfirm({
      message: i18n("admin.customize.email_style.reset_confirm", {
        fieldName: i18n(`admin.customize.email_style.${this.fieldName}`),
      }),
      didConfirm: () => {
        this.styles.setField(
          this.fieldName,
          this.styles.get(`default_${this.fieldName}`)
        );
        this.notifyPropertyChange("editorContents");
      },
    });
  }

  <template>
    <AceEditor
      @content={{this.editorContents}}
      @onChange={{fn (mut this.editorContents)}}
      @mode={{this.currentEditorMode}}
      @editorId={{this.editorId}}
      @save={{@save}}
    />

    <div class="admin-footer">
      <div class="buttons">
        <DButton
          @action={{this.reset}}
          @disabled={{this.resetDisabled}}
          @label="admin.customize.email_style.reset"
          class="btn-default"
        />
      </div>
    </div>
  </template>
}
