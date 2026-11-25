import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ColorPalettePicker from "discourse/select-kit/components/color-palette-picker";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DSelectColorPalette from "discourse/ui-kit/select/recipes/color-palettes/d-select-color-palette";
import { i18n } from "discourse-i18n";

export default class ColorSchemeSelectBase extends Component {
  @service siteSettings;

  @tracked selectedBaseThemeId = this.args.model.colorSchemes?.[0]?.id;

  @action
  selectBase() {
    this.args.model.newColorSchemeWithBase(this.selectedBaseThemeId);
    this.args.closeModal();
  }

  <template>
    <DModal
      class="create-color-palette"
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{i18n "admin.customize.colors.select_base.title"}}
    >
      <:body>
        {{i18n "admin.customize.colors.select_base.description"}}
        {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
        {{#if this.siteSettings.enable_new_select_controls}}
          <DSelectColorPalette
            class="select-base-palette"
            @activeIds={{@model.activeColorSchemeIds}}
            @onChange={{fn (mut this.selectedBaseThemeId)}}
            @palettes={{@model.colorSchemes}}
            @texts={{hash
              ariaLabel=(i18n "admin.customize.colors.select_base.title")
            }}
            @value={{this.selectedBaseThemeId}}
          />
        {{else}}
          <ColorPalettePicker
            class="select-base-palette"
            @content={{@model.colorSchemes}}
            @onChange={{fn (mut this.selectedBaseThemeId)}}
            @value={{this.selectedBaseThemeId}}
          />
        {{/if}}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.selectBase}}
          @icon="plus"
          @label="admin.customize.new"
        />
      </:footer>
    </DModal>
  </template>
}
