import DComboButton from "discourse/ui-kit/d-combo-button";

declare const hasDrafts: boolean;
declare const variant: string;

// Asserts the group declares its own arguments while each yielded half keeps the
// full `DButton`/`DMenu` argument surface. Each valid usage must compile; each
// invalid usage must be flagged (a missing error fails pnpm lint:types via the
// glint-expect-error directives).
const Test = <template>
  {{! The group's own arguments, with the halves carrying theirs }}
  <DComboButton @btnTypeClass={{variant}} @hasMenu={{hasDrafts}} as |combo|>
    <combo.Button @disabled={{false}} @icon="plus" @label="topic.create" />
    <combo.Menu
      @autofocus={{true}}
      @identifier="drafts"
      @placement="bottom-end"
    >
      content
    </combo.Menu>
  </DComboButton>

  {{! Both group arguments are optional }}
  <DComboButton as |combo|>
    <combo.Button @translatedLabel="Action" />
    <combo.Menu>content</combo.Menu>
  </DComboButton>

  {{! Attributes reach the group's element and both halves }}
  <DComboButton aria-label="Group" class="group" as |combo|>
    <combo.Button class="half" id="act" />
    <combo.Menu aria-label="More" class="half" />
  </DComboButton>

  {{! @glint-expect-error - @hasMenu is a boolean, not a string }}
  <DComboButton @hasMenu="yes" as |combo|><combo.Button /></DComboButton>

  {{! @glint-expect-error - @btnTypeClass is a string, not a boolean }}
  <DComboButton @btnTypeClass={{true}} as |combo|><combo.Button
    /></DComboButton>

  {{! @glint-expect-error - the group rejects an unknown argument }}
  <DComboButton @totallyBogus={{true}} as |combo|><combo.Button
    /></DComboButton>

  <DComboButton as |combo|>
    {{! @glint-expect-error - the button half rejects an unknown argument }}
    <combo.Button @totallyBogus={{true}} />
    {{! @glint-expect-error - DButton's @disabled is a boolean }}
    <combo.Button @disabled="yes" />
    {{! @glint-expect-error - the menu half rejects an unknown argument }}
    <combo.Menu @totallyBogus={{true}} />
  </DComboButton>
</template>;

export default Test;
