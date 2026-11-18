import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { deepEqual } from "discourse/lib/object";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/** The id of a tile, also used in its element id. */
export type DTapTileId = string | number;

interface DTapTileSignature<T extends DTapTileId> {
  Args: {
    /** The id of this tile. */
    tileId: T;

    /** The id of the selected tile, usually yielded by `DTapTileGrid`. */
    activeTile?: DTapTileId | null;

    /** Called with this tile's id when it is clicked or Enter is pressed on it. */
    onChange: (tileId: T) => void;

    /** The ID of an icon shown before the content. */
    icon?: string;
  };

  Element: HTMLDivElement;

  Blocks: {
    /** The content of the tile. */
    default: [];
  };
}

export default class DTapTile<T extends DTapTileId> extends Component<
  DTapTileSignature<T>
> {
  get active() {
    return deepEqual(this.args.activeTile, this.args.tileId);
  }

  @action
  click() {
    this.args.onChange(this.args.tileId);
  }

  @action
  keyDown(e: KeyboardEvent) {
    if (e.key === "Enter") {
      e.stopPropagation();
      this.args.onChange(this.args.tileId);
    }
  }

  <template>
    <div
      role="button"
      tabindex="0"
      ...attributes
      aria-pressed={{if this.active "true" "false"}}
      class={{dConcatClass "tap-tile" (if this.active "active")}}
      id="tap_tile_{{@tileId}}"
      {{on "click" this.click}}
      {{on "keydown" this.keyDown}}
    >
      {{#if @icon}}
        {{dIcon @icon}}
      {{/if}}
      {{yield}}
    </div>
  </template>
}
