import Component from "@glimmer/component";
import type { TOC } from "@ember/component/template-only";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
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
    disabled?: boolean;
    move: () => void;
  };
}

/**
 * One destination in the move menu.
 *
 * An unavailable direction is disabled rather than removed, so the menu keeps
 * the same shape on every row and a destination never changes position under
 * the reader. Disabled outright rather than with `aria-disabled`: the practice
 * page reserves the ARIA spelling for state a reader cannot infer, and being at
 * the end of a list is not that — the list conveys the position, and pressing
 * the accelerator into the boundary says so out loud.
 *
 * Each destination carries its own modifier class, which is what lets a test
 * or a page object name the destination it wants rather than counting menu
 * positions that shift as soon as a group adds a cross-list entry.
 */
const MoveItem: TOC<MoveItemSignature> = <template>
  <DButton
    role="menuitem"
    class={{dConcatClass
      "btn-transparent d-reorderable-list__move-item"
      (concat "--" @target)
    }}
    @icon={{@icon}}
    @translatedLabel={{@label}}
    @action={{@move}}
    @disabled={{@disabled}}
  />
</template>;

/** What the shared move menu is told to act on. */
interface MoveMenuData {
  /** The list that owns the menu, asked for live row state as it renders. */
  list: {
    rowFor: (key: string) => Row<unknown> | undefined;
    siblings: () => { listId: string; listLabel: string }[];
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

  get siblings(): { listId: string; listLabel: string }[] {
    return this.args.data?.list.siblings() ?? [];
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

  <template>
    <DDropdownMenu
      role="menu"
      aria-label={{this.row.handleLabel}}
      {{dRovingFocus
        orientation="vertical"
        itemSelector=".d-reorderable-list__move-item"
        wrap=true
        tabStop=false
        itemsKey=this.siblings.length
      }}
      as |dropdown|
    >
      <dropdown.item role="none">
        <MoveItem
          @target="top"
          @icon="angles-up"
          @label={{i18n "reorder.move_to_top"}}
          @disabled={{this.row.disableUp}}
          @move={{fn this.move "top"}}
        />
      </dropdown.item>
      <dropdown.item role="none">
        <MoveItem
          @target="up"
          @icon="arrow-up"
          @label={{i18n "reorder.move_up"}}
          @disabled={{this.row.disableUp}}
          @move={{fn this.move "up"}}
        />
      </dropdown.item>
      <dropdown.item role="none">
        <MoveItem
          @target="down"
          @icon="arrow-down"
          @label={{i18n "reorder.move_down"}}
          @disabled={{this.row.disableDown}}
          @move={{fn this.move "down"}}
        />
      </dropdown.item>
      <dropdown.item role="none">
        <MoveItem
          @target="bottom"
          @icon="angles-down"
          @label={{i18n "reorder.move_to_bottom"}}
          @disabled={{this.row.disableDown}}
          @move={{fn this.move "bottom"}}
        />
      </dropdown.item>
      {{#if this.siblings.length}}
        {{! Not a separator: the attribute lands on the list item, and the rule
            it wraps is already one. Naming it here would nest a separator
            inside a separator instead of giving the menu a single one. }}
        <dropdown.divider role="none" />
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
