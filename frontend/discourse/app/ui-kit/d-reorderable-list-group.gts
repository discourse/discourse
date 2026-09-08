import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { tracked } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { isDestroying } from "@ember/destroyable";
import { guidFor } from "@ember/object/internals";
import { schedule } from "@ember/runloop";
import type {
  ReorderableGroupApi,
  ReorderableGroupMember,
  ReorderableMove,
} from "discourse/ui-kit/d-reorderable-list";

/**
 * Aliased to keep the masked expression below on one line. Spelled out it wraps,
 * which puts the `&` a line further down than the disable directive reaches, and
 * an unused directive is deleted by `--fix` while the error it covered stays.
 */
const FOLLOWING = Node.DOCUMENT_POSITION_FOLLOWING;

/**
 * Whether one element comes after another in the document.
 * `compareDocumentPosition` answers with a bitmask whose bits can combine, so
 * the one bit being asked about is masked out rather than compared against
 * the whole result.
 *
 * @param left - The element to look out from.
 * @param right - The element to place relative to it.
 */
function follows(left: HTMLElement, right: HTMLElement): boolean {
  // eslint-disable-next-line no-bitwise
  return Boolean(left.compareDocumentPosition(right) & FOLLOWING);
}

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
 * enabled member that carries a `@listLabel` also appears as a destination in
 * the other members' move menus, which is how a cross-list move is reachable
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
  /** Keeps registry writes out of the member-construction render pass. */
  @tracked generation = 0;

  /**
   * The yielded API. Built once — members hold onto it across their whole
   * life, so its identity must not churn with renders.
   */
  api: ReorderableGroupApi = {
    token: `d-reorderable-list-group:${guidFor(this)}`,
    generation: () => this.generation,
    registerMember: (member: ReorderableGroupMember) => {
      const displaced = this.#members.get(member.listId);
      this.#members.set(member.listId, member);
      schedule("afterRender", () => {
        if (!isDestroying(this)) {
          this.generation++;
        }
      });

      // A re-render builds the replacement before tearing down what it
      // replaces, so a collision here is usually churn, and churn leaves a
      // detached element once the render settles where distinct lists do not.
      // Guarded with DEBUG because `assert` compiles away in production while
      // the scheduling around it would not.
      if (DEBUG && displaced && displaced !== member) {
        schedule("afterRender", () => {
          if (isDestroying(this)) {
            return;
          }
          assert(
            `d-reorderable-list-group: duplicate listId "${member.listId}" — every member needs a unique listId`,
            !displaced.element()?.isConnected
          );
        });
      }

      return () => {
        // Identity-checked so a departing member cannot evict the one that took
        // its place.
        if (this.#members.get(member.listId) === member) {
          this.#members.delete(member.listId);
          schedule("afterRender", () => {
            if (!isDestroying(this)) {
              this.generation++;
            }
          });
        }
      };
    },
    lookupMember: (listId: string) => this.#members.get(listId),
    siblings: (listId: string) =>
      this.#ordered()
        .filter(
          (member) =>
            member.listId !== listId &&
            !member.disabled() &&
            member.listLabel() !== undefined
        )
        .map((member) => ({
          listId: member.listId,
          listLabel: member.listLabel()!,
        })),
    neighbour: (listId: string, direction: "previous" | "next") => {
      const ordered = this.#ordered().filter((member) => !member.disabled());
      const index = ordered.findIndex((member) => member.listId === listId);
      if (index === -1) {
        return undefined;
      }
      return ordered[direction === "next" ? index + 1 : index - 1];
    },
    onMove: (move: ReorderableMove) => this.args.onMove(move),
  };
  /**
   * The registered members, by listId.
   *
   * Deliberately NOT tracked. Members register during construction, so a
   * reactive write here could follow another member's render-time read in the
   * same pass. The separately tracked generation changes only after render.
   */
  #members = new Map<string, ReorderableGroupMember>();

  /**
   * The registered members in document order, never registration order, which
   * stops matching the page as soon as the members themselves are reordered.
   * Members that have not rendered yet are dropped, having no position to
   * sort on.
   */
  #ordered(): ReorderableGroupMember[] {
    return [...this.#members.values()]
      .filter((member) => member.element())
      .sort((left, right) =>
        follows(left.element()!, right.element()!) ? -1 : 1
      );
  }

  <template>{{yield this.api}}</template>
}
