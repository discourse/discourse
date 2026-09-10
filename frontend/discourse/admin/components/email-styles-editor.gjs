/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import CodeEditor from "discourse/components/code-editor";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

@tagName("")
export default class EmailStylesEditor extends Component {
  @service dialog;

  @computed("styles", "fieldName")
  get editorContents() {
    return this.styles[this.fieldName];
  }

  set editorContents(value) {
    this.styles.setField(this.fieldName, value);
  }

  @computed("fieldName")
  get currentEditorMode() {
    return this.fieldName === "css" ? "scss" : this.fieldName;
  }

  @computed("fieldName", "styles.html", "styles.css")
  get resetDisabled() {
    return (
      this.get(`styles.${this.fieldName}`) ===
      this.get(`styles.default_${this.fieldName}`)
    );
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
    <div ...attributes>
      <CodeEditor
        @language={{this.currentEditorMode}}
        @onChange={{fn (mut this.editorContents)}}
        @save={{@save}}
        @value={{this.editorContents}}
      />

      <div class="admin-footer">
        <div class="buttons">
          <DButton
            class="btn-default"
            @action={{this.reset}}
            @disabled={{this.resetDisabled}}
            @label="admin.customize.email_style.reset"
          />
        </div>
      </div>
    </div>
  </template>
}
