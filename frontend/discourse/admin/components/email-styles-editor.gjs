import Component from "@glimmer/component";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import AceEditor from "discourse/components/ace-editor";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default class EmailStylesEditor extends Component {
  @service dialog;

  get editorContents() {
    return get(this.args.styles, this.args.fieldName);
  }

  get currentEditorMode() {
    return this.args.fieldName === "css" ? "scss" : this.args.fieldName;
  }

  get resetDisabled() {
    return (
      get(this.args.styles, this.args.fieldName) ===
      get(this.args.styles, `default_${this.args.fieldName}`)
    );
  }

  @action
  updateEditorContents(value) {
    this.args.styles.setField(this.args.fieldName, value);
  }

  @action
  reset() {
    this.dialog.yesNoConfirm({
      message: i18n("admin.customize.email_style.reset_confirm", {
        fieldName: i18n(`admin.customize.email_style.${this.args.fieldName}`),
      }),
      didConfirm: () => {
        this.updateEditorContents(
          get(this.args.styles, `default_${this.args.fieldName}`)
        );
      },
    });
  }

  <template>
    <div ...attributes>
      <AceEditor
        @content={{this.editorContents}}
        @editorId={{@fieldName}}
        @mode={{this.currentEditorMode}}
        @onChange={{this.updateEditorContents}}
        @save={{@save}}
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
