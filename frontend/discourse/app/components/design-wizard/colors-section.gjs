import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { swatchStyle } from "discourse/lib/design-wizard-preview";
import { NO_PALETTE_KEY } from "discourse/services/design-wizard";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

function paletteRowStatus(off, otherOff) {
  if (off) {
    return i18n("design_wizard.colors.mode_off");
  }
  return otherOff
    ? i18n("design_wizard.colors.used_for_both_modes")
    : i18n("design_wizard.colors.site_default");
}

const PaletteRow = <template>
  <div
    aria-label={{@groupLabel}}
    class="design-wizard__palette-row"
    data-mode={{@mode}}
    role="group"
  >
    <div class="design-wizard__palette-row-header">
      <h4 class="design-wizard__palette-row-title">{{@title}}</h4>
      <span class="design-wizard__palette-row-status">{{@status}}</span>
    </div>
    <div class="design-wizard__palette-cards">
      {{#each @pairs as |pair|}}
        {{#let
          (if @off false (eq pair.key @selectedKey))
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
              {{#if pair.dark_only}}
                {{dIcon "moon" label=(i18n "design_wizard.colors.dark_only")}}
              {{/if}}
            </span>
          </button>
        {{/let}}
      {{/each}}
      {{! one mode needs a palette of its own for the other to fall back on }}
      <button
        aria-pressed={{if @off "true" "false"}}
        class="design-wizard__palette-card --none {{if @off '--selected'}}"
        data-pair-key={{NO_PALETTE_KEY}}
        disabled={{@otherOff}}
        type="button"
        {{on "click" (fn @onSelect @mode NO_PALETTE_KEY)}}
      >
        <span aria-hidden="true" class="design-wizard__palette-preview --none">
          {{dIcon "ban"}}
        </span>
        <span class="design-wizard__palette-name">
          <span class="design-wizard__palette-name-text">
            {{i18n "design_wizard.colors.none"}}
          </span>
        </span>
      </button>
    </div>
  </div>
</template>;

const DesignWizardColorsSection = <template>
  <div class="design-wizard__color">
    <p class="design-wizard__color-description">
      {{i18n "design_wizard.colors.description"}}
    </p>

    {{#if @lightPairs.length}}
      <PaletteRow
        @groupLabel={{i18n "design_wizard.colors.light_mode_group"}}
        @mode="light"
        @off={{@lightOff}}
        @onSelect={{@onSelectPalette}}
        @otherOff={{@darkOff}}
        @pairs={{@lightPairs}}
        @selectedKey={{@selectedLightKey}}
        @status={{paletteRowStatus @lightOff @darkOff}}
        @title={{i18n "design_wizard.colors.light_mode"}}
      />
    {{/if}}

    {{#if @darkPairs.length}}
      <PaletteRow
        @groupLabel={{i18n "design_wizard.colors.dark_mode_group"}}
        @mode="dark"
        @off={{@darkOff}}
        @onSelect={{@onSelectPalette}}
        @otherOff={{@lightOff}}
        @pairs={{@darkPairs}}
        @selectedKey={{@selectedDarkKey}}
        @status={{paletteRowStatus @darkOff @lightOff}}
        @title={{i18n "design_wizard.colors.dark_mode"}}
      />
    {{/if}}

    {{! the region stays mounted so the note is announced when it appears }}
    <div aria-live="polite" class="design-wizard__palette-note-region">
      {{#if @singlePaletteName}}
        <p class="design-wizard__palette-note">
          {{dIcon "circle-info"}}
          <span>
            {{i18n
              "design_wizard.colors.single_palette_note"
              name=@singlePaletteName
            }}
          </span>
        </p>
      {{/if}}
    </div>
  </div>
</template>;

export default DesignWizardColorsSection;
