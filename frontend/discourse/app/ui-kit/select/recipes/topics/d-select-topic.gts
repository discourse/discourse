import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelect, {
  type DSelectSignature,
} from "discourse/ui-kit/select/d-select";
import {
  TopicOption,
  TopicSelection,
} from "discourse/ui-kit/select/recipes/topics/-internals/topic-renderers";
import {
  findHeldTopics,
  searchTopics,
} from "discourse/ui-kit/select/recipes/topics/-internals/topic-search";
import {
  type SelectTopicTextKey,
  TOPIC_TEXTS,
  type TopicPickerArchetype,
  topicPickerName,
  topicSearchPlaceholder,
} from "discourse/ui-kit/select/recipes/topics/-internals/topic-texts";
import {
  emitTopicChange,
  type TopicChangeHandler,
  unresolvedTopic,
} from "discourse/ui-kit/select/recipes/topics/-internals/topic-values";
import type {
  SelectItem,
  SelectTexts,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** The topic picker's arguments and the engine's forwarded presentation contract. */
interface DSelectTopicSignature {
  Args: Pick<
    DSelectSignature["Args"],
    | "ariaLabelledBy"
    | "clearable"
    | "describedBy"
    | "disabled"
    | "id"
    | "identifier"
    | "instanceContext"
    | "invalid"
    | "legacyKind"
    | "maximum"
    | "maxVisibleChips"
    | "onClose"
    | "variant"
  > & {
    /** Held topic ids. */
    value?: number | readonly number[] | null;
    /** Holds several topics; defaults to one, as DSelect does. */
    multiple?: boolean;
    /**
     * Search filters added to every query, such as `status:public`. With filters, topics are
     * listed before anything is typed.
     */
    additionalFilters?: string;
    /**
     * The archetype a typed search is restricted to: regular topics by default, or messages.
     * `null` searches every topic the term finds.
     */
    archetype?: TopicPickerArchetype | null;
    /** Held topics already in hand, shown without a lookup. */
    topics?: readonly object[];
    /** The picker's texts, over its defaults: the engine's and `unresolved`. */
    texts?: SelectTexts<SelectTopicTextKey>;
    /** Receives the held ids and their topics: arrays when multiple, otherwise one id or `null`. */
    onChange?: TopicChangeHandler;
  };
  Element: HTMLElement;
  Blocks: Pick<DSelectSignature["Blocks"], "item" | "selection" | "footer">;
}

/**
 * Picks topics from the site search, by title, pasted URL or id. Held topics are looked up
 * together, whether or not the user muted them.
 */
export default class DSelectTopic extends Component<DSelectTopicSignature> {
  /**
   * The picker's texts, named after what it searches and whether it holds more than one. The
   * field invites a search, since a topic is found only by searching.
   */
  kindTexts: SelectTexts = {
    ...TOPIC_TEXTS,
    ariaLabel: (_values, context) =>
      topicPickerName({
        plural: context.multiple && this.args.maximum !== 1,
        archetype: this.archetype,
      }),
    placeholder: () => topicSearchPlaceholder(this.archetype),
    searchPlaceholder: () => topicSearchPlaceholder(this.archetype),
  };

  constructor(owner: Owner, args: DSelectTopicSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("DSelectTopic", args);
  }

  /** Regular topics unless the call site names another archetype, or none. */
  get archetype(): TopicPickerArchetype | null {
    return this.args.archetype === undefined ? "regular" : this.args.archetype;
  }

  get legacyKind() {
    return this.args.legacyKind ?? "topic-chooser";
  }

  get loadContext() {
    return {
      additionalFilters: this.args.additionalFilters,
      archetype: this.archetype,
    };
  }

  get valueItems() {
    return this.args.topics as SelectItem[] | undefined;
  }

  @action
  load(filter: string) {
    return searchTopics(filter, {
      additionalFilters: this.args.additionalFilters,
      archetype: this.archetype,
    });
  }

  @action
  onChange(value: SelectValue, items: SelectItem | SelectItem[] | null) {
    emitTopicChange(this.args.onChange, !!this.args.multiple, value, items);
  }

  <template>
    {{! TODO (select-kit-replacement-cleanup): Retain the legacy family classes during rollout. }}
    <DSelect
      ...attributes
      @ariaLabelledBy={{@ariaLabelledBy}}
      @clearable={{@clearable}}
      @createUnresolvedItem={{unresolvedTopic}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @kind="select-topic"
      @kindContext={{hash
        value=@value
        additionalFilters=@additionalFilters
        archetype=this.archetype
      }}
      @kindTexts={{this.kindTexts}}
      @labelField="title"
      @legacyKind={{this.legacyKind}}
      @load={{this.load}}
      @loadContext={{this.loadContext}}
      @maximum={{@maximum}}
      @maxVisibleChips={{@maxVisibleChips}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @onClose={{@onClose}}
      @resolveValues={{findHeldTopics}}
      @suppressFooter={{not (has-block "footer")}}
      @texts={{@texts}}
      @value={{@value}}
      @valueItems={{this.valueItems}}
      @variant={{@variant}}
    >
      <:item as |item options row|>
        {{#if (has-block "item")}}
          {{yield item options row to="item"}}
        {{else}}
          <TopicOption @item={{item}} />
        {{/if}}
      </:item>
      <:selection as |item options|>
        {{#if (has-block "selection")}}
          {{yield item options to="selection"}}
        {{else}}
          <TopicSelection @item={{item}} />
        {{/if}}
      </:selection>
      <:footer as |state options|>
        {{yield state options to="footer"}}
      </:footer>
    </DSelect>
  </template>
}
