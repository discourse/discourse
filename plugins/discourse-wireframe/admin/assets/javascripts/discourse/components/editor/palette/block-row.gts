import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { guidFor } from "@ember/object/internals";
import BlockThumbnail from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/block-thumbnail";
import type { BlockPaletteEntry } from "discourse/plugins/discourse-wireframe/discourse/lib/palette";

interface BlockRowSignature {
  /** The row element, so a caller can attach drag or other modifiers. */
  Element: HTMLDivElement;
  /** Row arguments. */
  Args: {
    /** The palette entry the row lists. */
    entry: BlockPaletteEntry;
    /** Called with the entry when the row is activated by pointer. */
    onActivate?: (entry: BlockPaletteEntry) => void;
    /** The pointer event that activates the row; `"click"` by default. */
    activateOn?: string;
  };
}

/**
 * One block in the palette list: its sketch, display name and description on
 * a single row. Navigated and activated by a `dRovingFocus` modifier on the
 * parent list (the row owns no keydown), so it carries `role="option"`.
 *
 * Purely presentational: it knows nothing about insertion or dragging.
 * Activation is reported via `@onActivate`, and the palette makes a row a drag
 * source by applying the drag modifier at the call site (the row splats
 * `...attributes`).
 *
 * The description is visible, so it doubles as the accessible description: the
 * accessible name is exactly the display name (an explicit `aria-label`), and
 * `aria-describedby` points at the description span.
 */
export default class BlockRow extends Component<BlockRowSignature> {
  /**
   * The pointer event that activates the row (see `@activateOn`).
   */
  get activateOn(): string {
    return this.args.activateOn ?? "click";
  }

  /**
   * A unique id for this row's description span, referenced by the row's
   * `aria-describedby`.
   */
  get descriptionId(): string {
    return `${guidFor(this)}-description`;
  }

  @action
  activate(): void {
    this.args.onActivate?.(this.args.entry);
  }

  <template>
    <div
      class="wireframe-block-row"
      role="option"
      aria-label={{@entry.displayName}}
      aria-describedby={{this.descriptionId}}
      data-block-name={{@entry.name}}
      {{on this.activateOn this.activate}}
      ...attributes
    >
      <BlockThumbnail
        class="wireframe-block-row__thumbnail"
        @thumbnail={{@entry.thumbnail}}
        @icon={{@entry.icon}}
      />
      <span class="wireframe-block-row__text">
        <span class="wireframe-block-row__name">{{@entry.displayName}}</span>
        <span
          id={{this.descriptionId}}
          class="wireframe-block-row__description"
        >{{@entry.description}}</span>
      </span>
    </div>
  </template>
}
