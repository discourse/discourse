import Component from "@glimmer/component";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import AceEditor from "discourse/components/ace-editor";
import getURL from "discourse/lib/get-url";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class EmailStylesEditor extends Component {
  @service dialog;
  @service site;
  @service siteSettings;

  get editorContents() {
    return get(this.args.styles, this.args.fieldName);
  }

  get currentEditorMode() {
    return this.args.fieldName === "css" ? "scss" : this.args.fieldName;
  }

  get defaultTheme() {
    return this.site.user_themes.find((theme) => theme.default);
  }

  get showThemeEmailFields() {
    return (
      this.args.fieldName === "html" &&
      this.defaultTheme?.theme_id > 0 &&
      this.siteSettings.enable_email_theme_header_and_footer
    );
  }

  get themePageUrl() {
    return getURL(`/admin/customize/themes/${this.defaultTheme.theme_id}`);
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
    <div class="email-styles-editor" ...attributes>
      {{#if this.showThemeEmailFields}}
        <div class="email-styles-editor__theme-fields alert alert-info">
          {{dIcon "circle-info"}}
          <div class="email-styles-editor__theme-fields-copy">
            <p>{{i18n
                "admin.customize.email_style.theme_fields_description"
              }}</p>
            <p>{{i18n
                "admin.customize.email_style.theme_fields_git_guidance"
              }}</p>
            <a
              class="email-styles-editor__theme-fields-link"
              href={{this.themePageUrl}}
            >
              {{i18n
                "admin.customize.email_style.theme_fields_edit"
                themeName=this.defaultTheme.name
              }}
            </a>
          </div>
        </div>
      {{/if}}

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
