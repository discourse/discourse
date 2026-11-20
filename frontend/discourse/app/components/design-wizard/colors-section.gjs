import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DSegmentedControl from "discourse/components/d-segmented-control";
import { swatchStyle } from "discourse/lib/design-wizard-preview";
import { PALETTE_MODES } from "discourse/services/design-wizard";
import { i18n } from "discourse-i18n";

// a mode is only on offer when there are palettes for it
function paletteModeItems(lightPairs, darkPairs) {
  const noLight = !lightPairs?.length;
  const noDark = !darkPairs?.length;

  return [
    {
      value: PALETTE_MODES.both,
      label: i18n("design_wizard.colors.modes.both"),
      disabled: noLight || noDark,
    },
    {
      value: PALETTE_MODES.light,
      label: i18n("design_wizard.colors.modes.light"),
      disabled: noLight,
    },
    {
      value: PALETTE_MODES.dark,
      label: i18n("design_wizard.colors.modes.dark"),
      disabled: noDark,
    },
  ];
}

function selectedName(pairs, key) {
  return pairs?.find((pair) => pair.key === key)?.name;
}

const PaletteRow = <template>
  <div
    aria-label={{@title}}
    class="design-wizard__palette-row"
    data-mode={{@mode}}
    role="group"
  >
    <div class="design-wizard__palette-row-header">
      <h4 class="design-wizard__palette-row-title">{{@title}}</h4>
      <span class="design-wizard__palette-row-selected">
        {{selectedName @pairs @selectedKey}}
      </span>
    </div>
    <div class="design-wizard__palette-cards">
      {{#each @pairs as |pair|}}
        {{#let
          (eq pair.key @selectedKey)
          (if (eq @mode "light") pair.light pair.dark)
          as |selected palette|
        }}
          <button
            aria-pressed={{if selected "true" "false"}}
            class="design-wizard__palette-card {{if selected '--selected'}}"
            data-pair-key={{pair.key}}
            type="button"
            {{on "click" (fn @onSelect @mode pair.key)}}
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
</template>;

const DesignWizardColorsSection = <template>
  <div class="design-wizard__color">
    {{#if (or @lightPairs.length @darkPairs.length)}}
      <DSegmentedControl
        class="design-wizard__palette-modes --full-width"
        @items={{paletteModeItems @lightPairs @darkPairs}}
        @label="design_wizard.colors.modes.label"
        @name="design-wizard-palette-mode"
        @onSelect={{@onSelectPaletteMode}}
        @value={{@paletteMode}}
      />
    {{/if}}

    <p class="design-wizard__color-description">
      {{i18n "design_wizard.colors.description"}}
    </p>

    {{#if (and @showsLightPalettes @lightPairs.length)}}
      <PaletteRow
        @mode="light"
        @onSelect={{@onSelectPalette}}
        @pairs={{@lightPairs}}
        @selectedKey={{@selectedLightKey}}
        @title={{i18n "design_wizard.colors.light_palette"}}
      />
    {{/if}}

    {{#if (and @showsDarkPalettes @darkPairs.length)}}
      <PaletteRow
        @mode="dark"
        @onSelect={{@onSelectPalette}}
        @pairs={{@darkPairs}}
        @selectedKey={{@selectedDarkKey}}
        @title={{i18n "design_wizard.colors.dark_palette"}}
      />
    {{/if}}
  </div>
</template>;

export default DesignWizardColorsSection;
