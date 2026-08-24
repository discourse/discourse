import Component from "@glimmer/component";
import { assert } from "@ember/debug";
import { isDestroyed, isDestroying } from "@ember/destroyable";
import { guidFor } from "@ember/object/internals";
import { schedule } from "@ember/runloop";
import type {
  ReorderableGroupApi,
  ReorderableGroupMember,
  ReorderableMove,
} from "discourse/ui-kit/d-reorderable-list";

interface DReorderableListGroupSignature {
  Args: {
    /**
     * The single move callback for every member list: in-list moves and
     * cross-list moves alike arrive here, already normalized. Return `false`
     * to veto the announcement.
     */
    onMove: (move: ReorderableMove) => void | false;
  };
  Blocks: {
    /** The member lists, each receiving the yielded API as `@group`. */
    default: [group: ReorderableGroupApi];
  };
}

/**
 * Connects several reorderable lists into one drag surface.
 *
 * The group is renderless: it inserts no element of its own, and its only
 * output is the API it yields. Member lists that receive it as `@group` share
 * one drag token — which is what lets a row dragged out of one member land in
 * another — and route every move through the group's single `@onMove`. Every
 * member that carries a `@listLabel` also appears as a destination in the
 * other members' move menus, which is how a cross-list move is reachable
 * without a pointer.
 *
 * Members register themselves on construction and deregister on destruction,
 * so a drop whose source member has since been torn down resolves to nothing
 * and is refused silently.
 *
 * @example
 * ```gjs
 * <DReorderableListGroup @onMove={{this.applyMove}} as |group|>
 *   <DReorderableList @group={{group}} @listId="primary" ... />
 *   <DReorderableList @group={{group}} @listId="secondary" ... />
 * </DReorderableListGroup>
 * ```
 */
export default class DReorderableListGroup extends Component<DReorderableListGroupSignature> {
  /**
   * The yielded API. Built once — members hold onto it across their whole
   * life, so its identity must not churn with renders.
   */
  api: ReorderableGroupApi = {
    token: `d-reorderable-list-group:${guidFor(this)}`,
    registerMember: (member: ReorderableGroupMember) => {
      if (this.#members.has(member.listId)) {
        // Reported after render rather than thrown here: registration happens
        // during a member's construction, and an exception unwinding a
        // half-built render corrupts it. The duplicate is refused either way.
        schedule("afterRender", () => {
          if (isDestroying(this) || isDestroyed(this)) {
            return;
          }
          assert(
            `d-reorderable-list-group: duplicate listId "${member.listId}" — every member needs a unique listId`,
            false
          );
        });
        return () => {};
      }
      this.#members.set(member.listId, member);
      return () => {
        if (this.#members.get(member.listId) === member) {
          this.#members.delete(member.listId);
        }
      };
    },
    lookupMember: (listId: string) => this.#members.get(listId),
    siblings: (listId: string) =>
      [...this.#members.values()]
        .filter(
          (member) => member.listId !== listId && member.listLabel !== undefined
        )
        .map((member) => ({
          listId: member.listId,
          listLabel: member.listLabel!,
        })),
    onMove: (move: ReorderableMove) => this.args.onMove(move),
  };
  /**
   * The registered members, by listId.
   *
   * Deliberately NOT tracked. Members register during their own construction,
   * so the first list registers, renders, and would read this set before the
   * second list exists — a read followed by a write inside one render pass,
   * which is the backtracking-rerender error. Nothing reads it during render
   * instead: `siblings` is consulted when a move menu opens, by which point
   * every member has long since registered.
   */
  #members = new Map<string, ReorderableGroupMember>();

  <template>{{yield this.api}}</template>
}
