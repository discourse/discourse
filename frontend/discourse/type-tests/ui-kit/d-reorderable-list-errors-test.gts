import DReorderableList, {
  type ReorderableMove,
} from "discourse/ui-kit/d-reorderable-list";
import DReorderableListGroup from "discourse/ui-kit/d-reorderable-list-group";

interface Section {
  id: string;
  name: string;
}

interface Tag {
  slug: string;
}

declare const sections: Section[];
declare const tags: Tag[];
declare function applySectionMove(move: ReorderableMove<Section>): void;
declare function label(section: Section): string;
declare function tagLabel(tag: Tag): string;

const Test = <template>
  <DReorderableList
    {{! @glint-expect-error - @controls is a closed union; "split" is not a member }}
    @controls="split"
    @items={{sections}}
    @label={{label}}
  >
    <:row as |section|>{{section.name}}</:row>
  </DReorderableList>

  <DReorderableList
    {{! @glint-expect-error - @allowCreate is a flag, not a string }}
    @allowCreate="yes"
    @items={{sections}}
    @label={{label}}
  >
    <:row as |section|>{{section.name}}</:row>
  </DReorderableList>

  <DReorderableList
    @items={{sections}}
    @label={{label}}
    {{! @glint-expect-error - @removeIcon names an icon, so it is a string }}
    @removeIcon={{true}}
  >
    <:row as |section|>{{section.name}}</:row>
  </DReorderableList>

  <DReorderableListGroup @onMove={{applySectionMove}} as |groupApi|>
    <DReorderableList
      {{! @glint-expect-error - a member's items must be what the group's handler takes }}
      @group={{groupApi}}
      @items={{tags}}
      @label={{tagLabel}}
      @listId="tags"
    >
      <:row as |tag|>{{tag.slug}}</:row>
    </DReorderableList>
  </DReorderableListGroup>
</template>;

export { Test };
