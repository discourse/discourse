import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { LinkTo } from "@ember/routing";
import DSegmentedControl from "discourse/components/d-segmented-control";
import { swatchStyle } from "discourse/lib/design-wizard-preview";
import { PALETTE_MODES } from "discourse/services/design-wizard";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

function paletteModeItems(availableModes) {
  return Object.values(PALETTE_MODES).map((mode) => ({
    value: mode,
    label: i18n(`design_wizard.colors.modes.${mode}`),
    disabled: !availableModes?.includes(mode),
  }));
}

const DesignWizardColorsSection = <template>
  <div class="design-wizard__color">
    {{#if @availableModes.length}}
      <DSegmentedControl
        class="design-wizard__palette-modes --full-width"
        @items={{paletteModeItems @availableModes}}
        @label="design_wizard.colors.modes.label"
        @name="design-wizard-palette-mode"
        @onSelect={{@onSelectPaletteMode}}
        @value={{@paletteMode}}
      />
    {{/if}}

    {{#if @pairs.length}}
      <div
        aria-label={{i18n "design_wizard.colors.palette"}}
        class="design-wizard__palette-row"
        data-mode={{@colorMode}}
        role="group"
      >
        <div class="design-wizard__palette-cards">
          {{#each @pairs as |pair|}}
            {{#let
              (eq pair.key @selectedKey)
              (if (eq @colorMode "dark") pair.dark pair.light)
              as |selected palette|
            }}
              <button
                aria-pressed={{if selected "true" "false"}}
                class="design-wizard__palette-card {{if selected '--selected'}}"
                data-pair-key={{pair.key}}
                type="button"
                {{on "click" (fn @onSelectPalette pair.key)}}
              >
                <span
                  aria-hidden="true"
                  class="design-wizard__palette-preview"
                  style={{swatchStyle palette}}
                ></span>
                <span class="design-wizard__palette-name">
                  <span
                    class="design-wizard__palette-name-text"
                  >{{pair.name}}</span>
                </span>
              </button>
            {{/let}}
          {{/each}}
        </div>
      </div>
    {{/if}}

    <p class="design-wizard__manage-palettes">
      {{i18n "design_wizard.colors.manage_palettes_prompt"}}
      <LinkTo
        class="design-wizard__manage-palettes-link"
        @route="adminConfig.colorPalettes"
      >
        {{i18n "design_wizard.colors.manage_palettes"}}
        {{dIcon "arrow-right"}}
      </LinkTo>
    </p>
  </div>
</template>;

export default DesignWizardColorsSection;
