/* eslint-disable ember/no-classic-components */
import { tracked } from "@glimmer/tracking";
import Component from "@ember/component";
import { fn } from "@ember/helper";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { tagName } from "@ember-decorators/component";
import AceEditor from "discourse/components/ace-editor";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

@tagName("")
export default class EmailStylesEditor extends Component {
  @service dialog;

  @tracked _editorIdOverride;

  @computed("fieldName")
  get editorId() {
    if (this._editorIdOverride !== undefined) {
      return this._editorIdOverride;
    }
    return this.fieldName;
  }

  set editorId(value) {
    this._editorIdOverride = value;
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
    <div ...attributes>
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
    </div>
  </template>
}
