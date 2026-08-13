import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { modifier } from "ember-modifier";
import { eq } from "discourse/truth-helpers";
import DDragHandle from "discourse/ui-kit/d-drag-handle";
import DReorderButtons from "discourse/ui-kit/d-reorder-buttons";
import DResizeHandles from "discourse/ui-kit/d-resize-handles";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import { i18n } from "discourse-i18n";

/** Drop-position states shown as static swatches beside the live examples. */
const POSITIONS = [
  { state: "--drag-above", label: "above" },
  { state: "--drag-below", label: "below" },
  { state: "--drag-left", label: "left" },
  { state: "--drag-right", label: "right" },
  { state: "--drag-inside", label: "inside" },
];

/** Smallest dimension the resize example permits. */
const MIN_SIZE = 60;

class ReorderRow extends Component {
  /** The grip element registered as this row's drag handle. */
  @tracked gripElement;

  captureGrip = modifier((element) => {
    this.gripElement = element;
    return () => (this.gripElement = undefined);
  });

  get dragHandleLabel() {
    return i18n("styleguide.sections.drag_and_drop.drag_handle", {
      item: this.args.item.label,
    });
  }

  get moveDownLabel() {
    return i18n("styleguide.sections.drag_and_drop.move_down", {
      item: this.args.item.label,
    });
  }

  get moveUpLabel() {
    return i18n("styleguide.sections.drag_and_drop.move_up", {
      item: this.args.item.label,
    });
  }

  @action
  onDrop({ source, position }) {
    this.args.onDrop(source.data.item, this.args.item, position);
  }

  <template>
    <li
      {{dDragAndDropSource
        type="styleguide-row"
        data=(hash item=@item)
        dragHandle=this.gripElement
      }}
      {{dDragAndDropTarget
        accepts="styleguide-row"
        acceptsSelf=false
        onDrop=this.onDrop
      }}
      class="styleguide-drag-and-drop__row"
    >
      <DDragHandle
        {{this.captureGrip}}
        @label={{this.dragHandleLabel}}
        class="styleguide-drag-and-drop__drag-handle"
      />

      <span class="styleguide-drag-and-drop__row-label">{{@item.label}}</span>

      <DReorderButtons
        @onMoveUp={{fn @onMoveUp @item}}
        @onMoveDown={{fn @onMoveDown @item}}
        @disableUp={{eq @index 0}}
        @disableDown={{eq @index @lastIndex}}
        @upLabel={{this.moveUpLabel}}
        @downLabel={{this.moveDownLabel}}
        class="styleguide-drag-and-drop__reorder-buttons"
      />
    </li>
  </template>
}

export default class DragAndDropExample extends Component {
  @service a11y;

  @tracked
  items = [
    {
      id: "alpha",
      label: i18n("styleguide.sections.drag_and_drop.items.alpha"),
    },
    {
      id: "bravo",
      label: i18n("styleguide.sections.drag_and_drop.items.bravo"),
    },
    {
      id: "charlie",
      label: i18n("styleguide.sections.drag_and_drop.items.charlie"),
    },
  ];
  @tracked width = 220;
  @tracked height = 120;

  positions = POSITIONS;
  #startWidth = 0;
  #startHeight = 0;

  get boxStyle() {
    return trustHTML(`width: ${this.width}px; height: ${this.height}px;`);
  }

  get lastIndex() {
    return this.items.length - 1;
  }

  @action
  moveDown(item) {
    this.#reorder(item, this.items.indexOf(item) + 1);
  }

  @action
  moveUp(item) {
    this.#reorder(item, this.items.indexOf(item) - 1);
  }

  @action
  onDrop(item, target, position) {
    const fromIndex = this.items.indexOf(item);
    const targetIndex = this.items.indexOf(target);
    let toIndex = position === "before" ? targetIndex : targetIndex + 1;
    if (fromIndex < toIndex) {
      toIndex -= 1;
    }
    this.#reorder(item, toIndex);
  }

  @action
  onResizeStart() {
    this.#startWidth = this.width;
    this.#startHeight = this.height;
  }

  /** Maps pointer movement onto the dimensions affected by a compass handle. */
  @action
  onResize(direction, { delta }) {
    if (direction.includes("e")) {
      this.width = Math.max(MIN_SIZE, this.#startWidth + delta.x);
    }
    if (direction.includes("w")) {
      this.width = Math.max(MIN_SIZE, this.#startWidth - delta.x);
    }
    if (direction.includes("s")) {
      this.height = Math.max(MIN_SIZE, this.#startHeight + delta.y);
    }
    if (direction.includes("n")) {
      this.height = Math.max(MIN_SIZE, this.#startHeight - delta.y);
    }
  }

  #reorder(item, toIndex) {
    const fromIndex = this.items.indexOf(item);
    if (
      fromIndex === -1 ||
      toIndex < 0 ||
      toIndex >= this.items.length ||
      fromIndex === toIndex
    ) {
      return;
    }

    const next = [...this.items];
    next.splice(fromIndex, 1);
    next.splice(toIndex, 0, item);
    this.items = next;

    this.a11y.announce(
      i18n("reorder_announcement", {
        label: item.label,
        position: toIndex + 1,
        total: next.length,
      })
    );
  }

  <template>
    <div class="styleguide-drag-and-drop">
      <section class="styleguide-drag-and-drop__positions">
        <h3>{{i18n "styleguide.sections.drag_and_drop.positions_title"}}</h3>
        <p>{{i18n
            "styleguide.sections.drag_and_drop.positions_description"
          }}</p>

        <div class="styleguide-drag-and-drop__swatches">
          {{#each this.positions key="state" as |position|}}
            <div class="styleguide-drag-and-drop__swatch">
              <div
                data-drop-target
                class={{dConcatClass
                  "styleguide-drag-and-drop__box"
                  position.state
                }}
              >
                {{i18n
                  (concat
                    "styleguide.sections.drag_and_drop.positions."
                    position.label
                  )
                }}
              </div>
              <code>{{position.state}}</code>
            </div>
          {{/each}}
        </div>
      </section>

      <section class="styleguide-drag-and-drop__external">
        <h3>{{i18n "styleguide.sections.drag_and_drop.external_title"}}</h3>
        <p>{{i18n "styleguide.sections.drag_and_drop.external_description"}}</p>

        <div class="styleguide-drag-and-drop__swatches">
          <div class="styleguide-drag-and-drop__swatch">
            <div
              data-drop-target-external
              class="styleguide-drag-and-drop__box --drag-over-external"
            >
              {{i18n "styleguide.sections.drag_and_drop.external_label"}}
            </div>
            <code>--drag-over-external</code>
          </div>
        </div>
      </section>

      <section class="styleguide-drag-and-drop__live">
        <h3>{{i18n "styleguide.sections.drag_and_drop.live_title"}}</h3>
        <p>{{i18n "styleguide.sections.drag_and_drop.live_description"}}</p>

        <ul
          class="styleguide-drag-and-drop__list"
          aria-label={{i18n "styleguide.sections.drag_and_drop.live_title"}}
        >
          {{#each this.items key="id" as |item index|}}
            <ReorderRow
              @item={{item}}
              @index={{index}}
              @lastIndex={{this.lastIndex}}
              @onDrop={{this.onDrop}}
              @onMoveUp={{this.moveUp}}
              @onMoveDown={{this.moveDown}}
            />
          {{/each}}
        </ul>
      </section>

      <section class="styleguide-drag-and-drop__resize">
        <h3>{{i18n "styleguide.sections.drag_and_drop.resize_title"}}</h3>
        <p>{{i18n "styleguide.sections.drag_and_drop.resize_description"}}</p>

        <div
          class="styleguide-drag-and-drop__resizable"
          style={{this.boxStyle}}
        >
          {{this.width}}&nbsp;&times;&nbsp;{{this.height}}
          <DResizeHandles
            @handleClass="styleguide-drag-and-drop__handle"
            @onResizeStart={{this.onResizeStart}}
            @onResize={{this.onResize}}
          />
        </div>
      </section>
    </div>
  </template>
}
