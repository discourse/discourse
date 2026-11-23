import type { TOC } from "@ember/component/template-only";
import { concat, hash } from "@ember/helper";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { number } from "discourse/lib/formatter";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

interface DStatTileSignature {
  Args: {
    /** The name of the stat. */
    label: string;

    /** An explanation of the stat, shown in a tooltip next to the label. */
    tooltip?: string;

    /** A URL the value links to. */
    url?: string;

    /** The raw value. It is shown in a compact form and as the value's title. */
    value?: number | string;

    /** The value to show as is, in place of the compact `@value`. */
    formattedValue?: number | string;
  };
}

const DStatTile: TOC<DStatTileSignature> = <template>
  <div class="d-stat-tile" role="group">
    <div class="d-stat-tile__top">
      <span class="d-stat-tile__label">{{@label}}</span>
      {{#if @tooltip}}
        <DTooltip
          class="d-stat-tile__tooltip"
          @content={{@tooltip}}
          @icon="circle-question"
        />
      {{/if}}
    </div>
    {{#if @url}}
      <a class="d-stat-tile__value" href={{@url}} title={{@value}}>
        {{if @formattedValue @formattedValue (number @value)}}
      </a>
    {{else}}
      <span class="d-stat-tile__value" title={{@value}}>
        {{if @formattedValue @formattedValue (number @value)}}
      </span>
    {{/if}}
  </div>
</template>;

interface DStatTilesSignature {
  Args: {
    /** A layout variant, added to the container as a `--<format>` class, such as `compact`. */
    format?: string;
  };

  Element: HTMLDivElement;

  Blocks: {
    default: [
      /** The components to render the tiles with. */
      tiles: {
        /** A single stat tile. */
        Tile: typeof DStatTile;
      },
    ];
  };
}

const DStatTiles: TOC<DStatTilesSignature> = <template>
  <div
    class={{dConcatClass "d-stat-tiles" (if @format (concat "--" @format))}}
    ...attributes
  >
    {{yield (hash Tile=DStatTile)}}
  </div>
</template>;

export default DStatTiles;
