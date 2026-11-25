import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ColorPalettePicker from "discourse/select-kit/components/color-palette-picker";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { PaletteOption } from "discourse/ui-kit/select/recipes/color-palettes/d-select-color-palette";
import DSelectColorPaletteList from "discourse/ui-kit/select/recipes/color-palettes/d-select-color-palette-list";
import { i18n } from "discourse-i18n";

export default class ColorSchemeSelectBase extends Component {
  @service siteSettings;

  @tracked selectedBaseThemeId = this.args.model.colorSchemes?.[0]?.id;

  get selectedBase() {
    return this.args.model.colorSchemes?.find(
      (scheme) => scheme.id === this.selectedBaseThemeId
    );
  }

  get selectedBaseBadge() {
    return this.args.model.activeColorSchemeIds?.includes(
      this.selectedBaseThemeId
    )
      ? i18n("user.color_schemes.picker.active")
      : undefined;
  }

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
      @title={{if
        this.siteSettings.enable_new_select_controls
        (i18n "admin.customize.colors.select_base.new_title")
        (i18n "admin.customize.colors.select_base.title")
      }}
    >
      <:body>
        {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
        {{#if this.siteSettings.enable_new_select_controls}}
          {{#if this.selectedBase}}
            <p class="select-base-intro">
              {{i18n "admin.customize.colors.select_base.copy_of"}}
            </p>
            <div class="select-base-summary">
              <PaletteOption
                @badge={{this.selectedBaseBadge}}
                @label={{this.selectedBase.name}}
                @record={{this.selectedBase}}
              />
            </div>
          {{/if}}
          <div class="select-base-label">
            {{i18n "admin.customize.colors.select_base.other_palettes"}}
          </div>
          <DSelectColorPaletteList
            class="select-base-palette"
            @activeIds={{@model.activeColorSchemeIds}}
            @hideSelected={{true}}
            @onChange={{fn (mut this.selectedBaseThemeId)}}
            @palettes={{@model.colorSchemes}}
            @texts={{hash
              ariaLabel=(i18n
                "admin.customize.colors.select_base.other_palettes"
              )
            }}
            @value={{this.selectedBaseThemeId}}
          />
        {{else}}
          {{i18n "admin.customize.colors.select_base.description"}}
          <ColorPalettePicker
            class="select-base-palette"
            @content={{@model.colorSchemes}}
            @onChange={{fn (mut this.selectedBaseThemeId)}}
            @value={{this.selectedBaseThemeId}}
          />
        {{/if}}
      </:body>
      <:footer>
        {{#if this.siteSettings.enable_new_select_controls}}
          <DButton
            class="btn-primary"
            @action={{this.selectBase}}
            @icon="plus"
            @label="admin.customize.colors.select_base.create"
          />
        {{else}}
          <DButton
            class="btn-primary"
            @action={{this.selectBase}}
            @icon="plus"
            @label="admin.customize.new"
          />
        {{/if}}
      </:footer>
    </DModal>
  </template>
}
