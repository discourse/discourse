import Component from "@glimmer/component";
import type { TOC } from "@ember/component/template-only";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import {
  CHORD_TARGETS,
  TARGET_CHORDS,
} from "discourse/ui-kit/d-reorderable-list/-internals/constants";
import type {
  MoveTarget,
  Row,
} from "discourse/ui-kit/d-reorderable-list/types";
import DShortcut from "discourse/ui-kit/d-shortcut";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";

interface MoveItemSignature {
  Args: {
    target: string;
    icon: string;
    label: string;
    move: () => void;
  };
}

/**
 * The accelerator a destination answers to, in binding spelling; undefined
 * for a destination with no accelerator, which the shortcut component renders
 * as nothing at all.
 *
 * @param target - The destination, as its own argument names it.
 */
function chordFor(target: string) {
  const key = TARGET_CHORDS[target as MoveTarget];
  return key ? `Alt+${key}` : undefined;
}

/**
 * One destination in the move menu.
 *
 * Only reachable destinations are rendered: an unavailable one would still
 * count in the set the menu publishes to assistive software. The accelerator
 * still reaches the boundary and speaks the refusal in the menu's place.
 *
 * Each destination carries its own modifier class, so a test or page object
 * can name the destination it wants rather than counting menu positions that
 * shift as soon as a group adds a cross-list entry.
 */
const MoveItem: TOC<MoveItemSignature> = <template>
  <DShortcut @keys={{chordFor @target}} as |shortcut|>
    {{! The block form renders no element of its own, so the item is still the
        menu's own child at runtime and the rule is reading the source rather
        than the output. }}
    {{! eslint-disable ember/template-require-context-role }}
    <DButton
      role="menuitem"
      class={{dConcatClass
        "btn-transparent d-reorderable-list__move-item"
        (concat "--" @target)
      }}
      aria-keyshortcuts={{shortcut.aria}}
      @icon={{@icon}}
      @translatedLabel={{@label}}
      @action={{@move}}
    >
      {{! The drawn keys stay out of the accessible name, which the
          keyshortcuts attribute already carries in its own spelling. }}
      <shortcut.Kbd class="d-reorderable-list__move-shortcut" />
    </DButton>
  </DShortcut>
</template>;

/** What the shared move menu is told to act on. */
interface MoveMenuData {
  /** The list that owns the menu, asked for live row state as it renders. */
  list: {
    rowFor: (key: string) => Row<unknown> | undefined;
    siblings: () => { listId: string; listLabel: string }[];
    canSpill: (target: MoveTarget) => boolean;
    onMenuMove: (key: string, target: MoveTarget) => void;
    onMenuMoveToList: (key: string, listId: string, close: () => void) => void;
  };

  /** The row the menu was opened from. */
  key: string;
}

interface MoveMenuSignature {
  Args: {
    data?: MoveMenuData;
    close?: () => void;
  };
}

/**
 * The destinations behind one handle.
 *
 * Rendered by the list's single menu instance rather than per row, so it reads
 * the row it was opened for out of `@data` and asks the list for that row's
 * live state. Boundary marks therefore reflect the list as it stands while the
 * menu is open, not as it stood when the row last rendered.
 *
 * A real menu, so the arrows that move between destinations are a pattern
 * assistive software already names rather than one this list invented. The
 * role goes on the list element here, not through the float's `contentRole`,
 * which reaches only the float's outer wrapper — too far out to own these
 * buttons as items.
 */
export default class MoveMenu extends Component<MoveMenuSignature> {
  get row(): Row<unknown> | undefined {
    return this.args.data?.list.rowFor(this.args.data.key);
  }

  /**
   * Whether a step is offered at all, which is not the same question as
   * whether it stays inside this list: a row at its own end still moves when
   * the list spills, and the destination is simply the next member.
   */
  get canMoveUp(): boolean {
    return !!this.row?.canMoveUp || this.#canSpill("up");
  }

  get canMoveDown(): boolean {
    return !!this.row?.canMoveDown || this.#canSpill("down");
  }

  /** Whether any direction survived, which is what a divider divides. */
  get hasDirections(): boolean {
    return this.canMoveUp || this.canMoveDown;
  }

  get siblings(): { listId: string; listLabel: string }[] {
    return this.args.data?.list.siblings() ?? [];
  }

  /**
   * An accelerator pressed inside the menu, routed to the same place choosing
   * the destination goes. Handled on the list element rather than on each
   * destination: a chord aimed at a boundary has no destination in the menu
   * to receive it, and the refusal still has to be spoken.
   *
   * @param event - The keydown that may carry a chord.
   */
  @action
  onKeydown(event: KeyboardEvent) {
    if (!event.altKey) {
      return;
    }
    const target = CHORD_TARGETS[event.key];
    const { data } = this.args;
    if (!target || !data) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    data.list.onMenuMove(data.key, target);
  }

  @action
  move(target: MoveTarget) {
    const { data } = this.args;
    data?.list.onMenuMove(data.key, target);
  }

  @action
  moveToList(listId: string) {
    const { data, close } = this.args;
    data?.list.onMenuMoveToList(data.key, listId, close ?? (() => {}));
  }

  /**
   * Whether the list would carry a row off its own end in this direction.
   *
   * @param target - The step being considered.
   */
  #canSpill(target: MoveTarget): boolean {
    return this.args.data?.list.canSpill(target) ?? false;
  }

  <template>
    <DDropdownMenu
      role="menu"
      aria-label={{this.row.handleLabel}}
      {{on "keydown" this.onKeydown}}
      {{dRovingFocus
        orientation="vertical"
        itemSelector=".d-reorderable-list__move-item"
        wrap=true
        tabStop=false
        itemsKey=this.siblings.length
      }}
      as |dropdown|
    >
      {{! The ends are this list's own by definition, so they are offered only
          while there is somewhere inside it left to go. The steps are offered
          more widely, since a spilling list answers them past its own edge. }}
      {{#if this.row.canMoveUp}}
        <dropdown.item role="none">
          <MoveItem
            @target="top"
            @icon="angles-up"
            @label={{i18n "reorder.move_to_top"}}
            @move={{fn this.move "top"}}
          />
        </dropdown.item>
      {{/if}}
      {{#if this.canMoveUp}}
        <dropdown.item role="none">
          <MoveItem
            @target="up"
            @icon="arrow-up"
            @label={{i18n "reorder.move_up"}}
            @move={{fn this.move "up"}}
          />
        </dropdown.item>
      {{/if}}
      {{#if this.canMoveDown}}
        <dropdown.item role="none">
          <MoveItem
            @target="down"
            @icon="arrow-down"
            @label={{i18n "reorder.move_down"}}
            @move={{fn this.move "down"}}
          />
        </dropdown.item>
      {{/if}}
      {{#if this.row.canMoveDown}}
        <dropdown.item role="none">
          <MoveItem
            @target="bottom"
            @icon="angles-down"
            @label={{i18n "reorder.move_to_bottom"}}
            @move={{fn this.move "bottom"}}
          />
        </dropdown.item>
      {{/if}}
      {{#if this.siblings.length}}
        {{#if this.hasDirections}}
          {{! Not role="separator": the attribute lands on the list item, and
              the rule it wraps is already one, so naming it here would nest a
              separator inside a separator. }}
          <dropdown.divider role="none" />
        {{/if}}
        {{#each this.siblings key="listId" as |sibling|}}
          <dropdown.item role="none">
            <MoveItem
              @target="list"
              {{! Deliberately not a directional arrow: the list has no idea
                where a sibling sits on the page, so an arrow would point the
                wrong way as often as not. }}
              @icon="right-left"
              @label={{i18n "reorder.move_to_list" list=sibling.listLabel}}
              @move={{fn this.moveToList sibling.listId}}
            />
          </dropdown.item>
        {{/each}}
      {{/if}}
    </DDropdownMenu>
  </template>
}
