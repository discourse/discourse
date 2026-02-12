import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { cssVarToColorSchemeName } from "../../lib/color-math";

export default class ApplyChangesModal extends Component {
  @tracked paletteName = "Styleguide Custom Palette";
  @tracked componentName = "Styleguide Custom Styles";
  @tracked loading = false;
  @tracked flashMessage = null;

  get cssEditorState() {
    return this.args.model.cssEditorState;
  }

  get baseColorOverrides() {
    return this.cssEditorState.getBaseColorOverrides();
  }

  get cssVariableOverrides() {
    return this.cssEditorState.getCssVariableOverrides();
  }

  get baseColorCount() {
    return this.baseColorOverrides.length;
  }

  get hasCssVariableOverrides() {
    return this.cssVariableOverrides.length > 0;
  }

  @action
  updatePaletteName(event) {
    this.paletteName = event.target.value;
  }

  @action
  updateComponentName(event) {
    this.componentName = event.target.value;
  }

  @action
  async applyChanges() {
    this.loading = true;
    this.flashMessage = null;

    try {
      if (this.baseColorCount > 0) {
        const colors = this.baseColorOverrides.map(([name, hex]) => ({
          name: cssVarToColorSchemeName(name),
          hex: hex.replace("#", ""),
        }));

        await ajax("/admin/color_schemes.json", {
          type: "POST",
          data: {
            color_scheme: {
              name: this.paletteName,
              base_scheme_id: "Light",
              colors,
            },
          },
        });
      }

      const themeCSS = this.cssEditorState.generateThemeCSS();
      if (themeCSS) {
        const componentResult = await ajax("/admin/themes.json", {
          type: "POST",
          data: {
            theme: {
              name: this.componentName,
              component: true,
              theme_fields: [
                {
                  name: "scss",
                  target: "common",
                  value: themeCSS,
                },
              ],
            },
          },
        });

        const componentId = componentResult.theme.id;
        const themesResult = await ajax("/admin/themes.json");
        const themes = themesResult.themes.filter(
          (t) => !t.component && (t.default || t.user_selectable)
        );

        for (const theme of themes) {
          const existingChildIds = theme.child_themes?.map((c) => c.id) || [];
          await ajax(`/admin/themes/${theme.id}.json`, {
            type: "PUT",
            data: {
              theme: {
                child_theme_ids: [...existingChildIds, componentId],
              },
            },
          });
        }
      }

      this.args.closeModal();
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @title={{i18n "styleguide.css_editor.modal.title"}}
      @flash={{this.flashMessage}}
      class="apply-changes-modal"
    >
      <:body>
        <p>{{i18n "styleguide.css_editor.modal.description"}}</p>

        {{#if this.baseColorCount}}
          <div class="apply-changes-modal__section">
            <label class="apply-changes-modal__label">
              {{i18n "styleguide.css_editor.modal.palette_name"}}
            </label>
            <input
              type="text"
              value={{this.paletteName}}
              class="apply-changes-modal__input"
              {{on "input" this.updatePaletteName}}
            />
            <div class="apply-changes-modal__summary">
              {{i18n
                "styleguide.css_editor.modal.palette_summary"
                count=this.baseColorCount
              }}
            </div>
          </div>
        {{/if}}

        {{#if this.hasCssVariableOverrides}}
          <div class="apply-changes-modal__section">
            <label class="apply-changes-modal__label">
              {{i18n "styleguide.css_editor.modal.component_name"}}
            </label>
            <input
              type="text"
              value={{this.componentName}}
              class="apply-changes-modal__input"
              {{on "input" this.updateComponentName}}
            />
            <div class="apply-changes-modal__summary">
              {{i18n "styleguide.css_editor.modal.component_summary"}}
            </div>
          </div>
        {{/if}}

        <p class="apply-changes-modal__note">
          {{i18n "styleguide.css_editor.modal.component_note"}}
        </p>
      </:body>
      <:footer>
        <DButton
          @action={{this.applyChanges}}
          @label="styleguide.css_editor.modal.apply"
          @disabled={{this.loading}}
          class="btn-primary"
        />
        <DButton
          @action={{@closeModal}}
          @label="styleguide.css_editor.modal.cancel"
          class="btn-default"
        />
      </:footer>
    </DModal>
  </template>
}
