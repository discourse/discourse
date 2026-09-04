// Keep this file free of @glint-expect-error directives so broken positive
// invocations cannot be masked by a negative assertion. Rejections live in
// d-reorderable-list-errors-test.gts.
import DReorderableList, {
  type ReorderableGroupApi,
  type ReorderableGroupMember,
  type ReorderableMove,
  type ReorderableRowApi,
} from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";

interface Section {
  id: string;
  name: string;
}

declare const sections: Section[];
declare function applyMove(move: ReorderableMove<Section>): void;
declare function label(section: Section): string;
declare function movable(section: Section): boolean;
declare function removeSection(section: Section, index: number): void;
declare const group: ReorderableGroupApi;

// The four interfaces are re-exported from the component's own module path,
// which is the only thing keeping the group's `import type` working. Nothing
// else in the repo pins that, so these two lines are the guard.
declare const member: ReorderableGroupMember;
declare const rowApi: ReorderableRowApi;
declare const someMove: ReorderableMove;

const usesNamedExports: string = [
  member.listId,
  someMove.fromList,
  rowApi.index.toString(),
].join("");

const Test = <template>
  {{! The minimum: items, a label, and somewhere to report the move }}
  <DReorderableList @items={{sections}} @label={{label}} @onMove={{applyMove}}>
    <:row as |section|>
      <span>{{section.name}}</span>
    </:row>
  </DReorderableList>

  {{! The row block yields the item first, then its controls }}
  <DReorderableList
    @items={{sections}}
    @key="id"
    @label={{label}}
    @movable={{movable}}
    @onMove={{applyMove}}
    @onRemove={{removeSection}}
    @removeIcon="trash-can"
  >
    <:row as |section controls|>
      <span>{{section.name}} {{controls.index}}</span>
    </:row>
  </DReorderableList>

  {{! Manual placement yields the pre-wired controls on the same block param }}
  <DReorderableList
    @items={{sections}}
    @key="id"
    @label={{label}}
    @controls="manual"
    @onMove={{applyMove}}
    @onRemove={{removeSection}}
  >
    <:row as |section controls|>
      <controls.handle />
      <span>{{section.name}}</span>
      {{! Manual mode lets the yielded remove control take its own buttonClass }}
      {{#if controls.remove}}
        <controls.remove @buttonClass="btn-default" />
      {{/if}}
    </:row>
  </DReorderableList>

  {{! The optional blocks, and the shell arguments that retag the elements }}
  <DReorderableList
    @items={{sections}}
    @key="id"
    @label={{label}}
    @onMove={{applyMove}}
    @tag="tbody"
    @itemTag="tr"
    @allowCreate={{true}}
    class="styled"
  >
    <:hint>Drag to reorder</:hint>
    <:header>Sections</:header>
    <:row as |section|>
      <td>{{section.name}}</td>
    </:row>
    <:empty>Nothing yet</:empty>
  </DReorderableList>

  {{! A member list routes its moves through the group instead }}
  <DReorderableListGroup @onMove={{applyMove}} as |groupApi|>
    <DReorderableList
      @group={{groupApi}}
      @listId="primary"
      @listLabel="Primary"
      @items={{sections}}
      @key="id"
      @label={{label}}
    >
      <:row as |section|>
        <span>{{section.name}}</span>
      </:row>
    </DReorderableList>
  </DReorderableListGroup>

  {{! A group API obtained elsewhere satisfies the same argument }}
  <DReorderableList
    @group={{group}}
    @listId="secondary"
    @items={{sections}}
    @key="id"
    @label={{label}}
  >
    <:row as |section|>
      <span>{{section.name}}</span>
    </:row>
  </DReorderableList>
</template>;

export { Test, usesNamedExports };
