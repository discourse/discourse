import DReorderableList from "discourse/ui-kit/d-reorderable-list";

interface Section {
  id: string;
  name: string;
}

declare const sections: Section[];
declare function label(section: Section): string;

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
</template>;

export { Test };
