import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import type Owner from "@ember/owner";
import { assertNoRemovedTextArgs } from "discourse/ui-kit/select/-internals/engine/select-texts";
import DSelectList from "discourse/ui-kit/select/d-select-list";
import type { MultiSelectRecipeArgs } from "discourse/ui-kit/select/recipes/-internals/recipe-args";
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
  SelectConfig,
  SelectOption,
  SelectRecord,
  SelectTexts,
  SelectValue,
} from "discourse/ui-kit/select/select-engine";

/** The persistent topic list's arguments. */
interface DSelectTopicListSignature {
  Args: MultiSelectRecipeArgs & {
    /** Held topic ids: an array, or one id or `null` when `@multiple` is false. */
    value?: number | readonly number[] | null;
    /** Holds several topics, as a list does by default; `false` makes a pick replace the held one. */
    multiple?: boolean;
    /** Hard selection cap, as `DSelectList` takes it. */
    maximum?: number | false;
    /**
     * Search filters added to every query, such as `@username in:created`. With filters, topics
     * are listed before anything is typed.
     */
    additionalFilters?: string;
    /**
     * The archetype a typed search is restricted to: regular topics by default, or messages.
     * `null` searches every topic the term finds.
     */
    archetype?: TopicPickerArchetype | null;
    /** Topic ids never offered, such as the topic being moved from. */
    exclude?: readonly number[];
    /** Held topics already in hand, shown without a lookup. */
    topics?: readonly object[];
    /** The picker's texts, over its defaults: the engine's and `unresolved`. */
    texts?: SelectTexts<SelectTopicTextKey>;
    /** Receives the held ids and their topics, in the shape `@multiple` gives the value. */
    onChange?: TopicChangeHandler;
    /** Native search-input id, for a label's for attribute. */
    id?: string;
    /** Additional search-input description ids. */
    describedBy?: string;
    /** Marks the search input invalid. */
    invalid?: boolean;
    /** Disables focus, editing and selection. */
    disabled?: boolean;
  };
  Element: HTMLDivElement;
  Blocks: {
    /** Custom option content. */
    option?: [
      /** The topic. */ record: SelectRecord,
      /** Resolved config. */ config: SelectConfig,
      /** The option itself, with its settings. */ option: SelectOption,
    ];
    /** Custom held-chip content. */
    selection?: [
      /** The held topic. */ record: SelectRecord,
      /** Resolved config. */ config: SelectConfig,
    ];
  };
}

/**
 * A persistent list of topics from the site search, for a panel or modal that picks topics
 * without a trigger. It searches, looks held topics up and draws rows as `DSelectTopic` does.
 */
export default class DSelectTopicList extends Component<DSelectTopicListSignature> {
  /** The list's texts, named after what it searches and whether it holds more than one. */
  kindTexts: SelectTexts = {
    ...TOPIC_TEXTS,
    ariaLabel: (_values, context) =>
      topicPickerName({
        plural: context.multiple && this.args.maximum !== 1,
        archetype: this.archetype,
      }),
    searchPlaceholder: () => topicSearchPlaceholder(this.archetype),
  };

  constructor(owner: Owner, args: DSelectTopicListSignature["Args"]) {
    super(owner, args);
    assertNoRemovedTextArgs("DSelectTopicList", args);
  }

  /** Regular topics unless the call site names another archetype, or none. */
  get archetype(): TopicPickerArchetype | null {
    return this.args.archetype === undefined ? "regular" : this.args.archetype;
  }

  get loadContext() {
    return {
      additionalFilters: this.args.additionalFilters,
      archetype: this.archetype,
      exclude: this.args.exclude ?? [],
    };
  }

  get valueRecords() {
    return this.args.topics as SelectRecord[] | undefined;
  }

  @action
  async load(filter: string) {
    const topics = await searchTopics(filter, {
      additionalFilters: this.args.additionalFilters,
      archetype: this.archetype,
    });
    const exclude = this.args.exclude ?? [];
    return topics.filter((topic) => !exclude.includes(topic.id as number));
  }

  @action
  onChange(value: SelectValue, records: SelectRecord | SelectRecord[] | null) {
    emitTopicChange(
      this.args.onChange,
      this.args.multiple ?? true,
      value,
      records
    );
  }

  <template>
    <DSelectList
      ...attributes
      @createUnresolvedRecord={{unresolvedTopic}}
      @describedBy={{@describedBy}}
      @disabled={{@disabled}}
      @id={{@id}}
      @identifier={{@identifier}}
      @instanceContext={{@instanceContext}}
      @invalid={{@invalid}}
      @kind="select-topic-list"
      @kindContext={{hash
        value=@value
        additionalFilters=@additionalFilters
        archetype=this.archetype
        exclude=@exclude
      }}
      @kindTexts={{this.kindTexts}}
      @labelField="title"
      @legacyKind={{@legacyKind}}
      @load={{this.load}}
      @loadContext={{this.loadContext}}
      @lockedValues={{@lockedValues}}
      @maximum={{@maximum}}
      @multiple={{@multiple}}
      @onChange={{this.onChange}}
      @resolveValues={{findHeldTopics}}
      @texts={{@texts}}
      @value={{@value}}
      @valueRecords={{this.valueRecords}}
    >
      <:option as |record config option|>
        {{#if (has-block "option")}}
          {{yield record config option to="option"}}
        {{else}}
          <TopicOption @record={{record}} />
        {{/if}}
      </:option>
      <:selection as |record config|>
        {{#if (has-block "selection")}}
          {{yield record config to="selection"}}
        {{else}}
          <TopicSelection @record={{record}} />
        {{/if}}
      </:selection>
    </DSelectList>
  </template>
}
