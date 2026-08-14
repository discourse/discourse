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
 * another — and route every move through the group's single `@onMove`. Arrow
 * moves stay within their own member by construction; only a drag crosses
 * lists.
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
    onMove: (move: ReorderableMove) => this.args.onMove(move),
  };
  /** The registered members, by listId. */
  #members = new Map<string, ReorderableGroupMember>();

  <template>{{yield this.api}}</template>
}
