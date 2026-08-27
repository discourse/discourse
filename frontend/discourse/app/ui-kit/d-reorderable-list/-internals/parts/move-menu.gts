import Component from "@glimmer/component";
import type { TOC } from "@ember/component/template-only";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { translateModKey } from "discourse/lib/utilities";
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
 * The accelerator a destination answers to, in the two forms it is published
 * in. Both name the key the platform names, as every other shortcut in core
 * does: a reader on a Mac presses one labelled Option, and would not recognize
 * the modifier's canonical name. They differ only in the separator, which the
 * announced form always carries. Absent for a destination with no accelerator,
 * which is what the item reads to decide whether to advertise one at all.
 *
 * @param target - The destination, as its own argument names it.
 */
function chordFor(target: string) {
  const key = TARGET_CHORDS[target as MoveTarget];
  if (!key) {
    return undefined;
  }
  return {
    keys: translateModKey(`Alt+${key}`, "+"),
    label: translateModKey(`Alt+${key}`),
  };
}

/**
 * One destination in the move menu.
 *
 * Only reachable destinations are rendered. A menu holding an unavailable one
 * counts it in the set it publishes, so a reader is told the menu has four
 * items while the cursor can land on two. The accelerator still reaches the
 * boundary and still speaks the refusal, which is where "already first" is
 * conveyed now that nothing stands in the menu to convey it.
 *
 * Each destination carries its own modifier class, which is what lets a test
 * or a page object name the destination it wants rather than counting menu
 * positions that shift as soon as a group adds a cross-list entry.
 */
const MoveItem: TOC<MoveItemSignature> = <template>
  {{#let (chordFor @target) as |chord|}}
    <DButton
      role="menuitem"
      class={{dConcatClass
        "btn-transparent d-reorderable-list__move-item"
        (concat "--" @target)
      }}
      aria-keyshortcuts={{chord.keys}}
      @icon={{@icon}}
      @translatedLabel={{@label}}
      @action={{@move}}
    >
      {{#if chord.label}}
        {{! Hidden from the accessible name, which the keyshortcuts attribute
            already carries: left visible it is read a second time, in a
            spelling that does not match the first. }}
        <kbd aria-hidden="true" class="d-reorderable-list__move-shortcut">
          {{~chord.label~}}
        </kbd>
      {{/if}}
    </DButton>
  {{/let}}
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
 * assistive software already names rather than one this list invented. The role
 * goes on the list element here, not through the float's `contentRole`, which
 * only reaches the wrapper two levels above these buttons — far enough out that
 * it could never own them as items.
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
   * An accelerator pressed inside the menu, which is where it is advertised.
   *
   * Routed to the same place choosing the destination goes, so the hint means
   * what it says. The keydown handler on the list element rather than on each
   * destination, because a chord aimed at a boundary has no destination in the
   * menu to receive it and the refusal still has to be spoken.
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
          {{! Not a separator: the attribute lands on the list item, and the
              rule it wraps is already one. Naming it here would nest a
              separator inside a separator instead of giving the menu a single
              one. Absent when no direction survives, since a rule below
              nothing divides nothing. }}
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
