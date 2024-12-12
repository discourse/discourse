import { hash } from "@ember/helper";
import { number } from "discourse/lib/formatter";
import DTooltip from "float-kit/components/d-tooltip";

const DStatTile = <template>
  <div class="d-stat-tile" role="group">
    <div class="d-stat-tile__top">
      <span class="d-stat-tile__label">{{@label}}</span>
      {{#if @tooltip}}
        <DTooltip
          class="d-stat-tile__tooltip"
          @icon="circle-question"
          @content={{@tooltip}}
        />
      {{/if}}
    </div>
    {{#if @url}}
      <a href={{@url}} class="d-stat-tile__value" title={{@value}}>
        {{number @value}}
      </a>
    {{else}}
      <span class="d-stat-tile__value" title={{@value}}>{{number @value}}</span>
    {{/if}}
  </div>
</template>;

const DStatTiles = <template>
  <div class="d-stat-tiles" ...attributes>
    {{yield (hash Tile=DStatTile)}}
  </div>
</template>;

export default DStatTiles;
