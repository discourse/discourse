import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { isEmpty } from "@ember/utils";
import { classNames } from "@ember-decorators/component";
import { makeArray } from "discourse/lib/helpers";
import { searchForTerm } from "discourse/lib/search";
import MultiSelect from "discourse/select-kit/components/multi-select";
import { selectKitOptions } from "discourse/select-kit/components/select-kit";
import TopicRow from "discourse/select-kit/components/topic-row";
import { i18n } from "discourse-i18n";
import { integerIdsFromValue, sameIds } from "../../../lib/workflows/id-values";
import ExpressionWrapper from "./expression-wrapper";

async function findTopics(term) {
  const results = await searchForTerm(term, {
    typeFilter: "topic",
    searchForId: true,
  });

  return makeArray(results?.posts)
    .map((post) => post.topic)
    .filter(Boolean);
}

@classNames("topic-selector")
@selectKitOptions({
  filterable: true,
  filterPlaceholder: "choose_topic.title.placeholder",
})
class TopicSelector extends MultiSelect {
  nameProperty = "title";
  labelProperty = "title";
  titleProperty = "title";

  modifyComponentForRow() {
    return TopicRow;
  }

  async search(filter) {
    if (isEmpty(filter)) {
      return [];
    }

    const selectedIds = new Set(this.value);
    const topics = await findTopics(filter);

    return topics.filter((topic) => !selectedIds.has(topic.id));
  }
}

export default class TopicControl extends Component {
  @tracked selectedTopics = [];

  constructor() {
    super(...arguments);
    this.hydrateSelectedTopics();
  }

  get topicIds() {
    return integerIdsFromValue(this.args.field.value);
  }

  @action
  hydrateSelectedTopics() {
    const shownIds = this.selectedTopics.map((topic) => topic.id);
    if (!sameIds(this.topicIds, shownIds)) {
      this.#updateSelectedTopics();
    }
  }

  @action
  handleChange(topicIds, topics) {
    this.selectedTopics = makeArray(topics);
    this.args.field.set(topicIds);
  }

  async #updateSelectedTopics() {
    const requestedIds = this.topicIds;
    const topics = await Promise.all(
      requestedIds.map((id) => this.#findTopic(id))
    );

    // A newer value may have arrived while we were fetching.
    if (this.isDestroying || !sameIds(this.topicIds, requestedIds)) {
      return;
    }

    // Keep unresolvable ids (deleted or hidden topics) visible so they can be removed.
    this.selectedTopics = topics.map(
      (topic, index) =>
        topic ?? {
          id: requestedIds[index],
          title: i18n("discourse_workflows.topic_control.unavailable_topic", {
            id: requestedIds[index],
          }),
        }
    );
  }

  async #findTopic(id) {
    const known = this.selectedTopics.find((topic) => topic.id === id);
    if (known) {
      return known;
    }

    try {
      const topics = await findTopics(String(id));
      return topics.find((topic) => topic.id === id) ?? null;
    } catch {
      return null;
    }
  }

  <template>
    <ExpressionWrapper
      @dynamicValueHint={{@dynamicValueHint}}
      @field={{@field}}
      @placeholder={{@placeholder}}
      @schema={{@schema}}
      @session={{@session}}
      @supportsExpression={{@supportsExpression}}
    >
      <TopicSelector
        @content={{this.selectedTopics}}
        @onChange={{this.handleChange}}
        @options={{hash translatedNone=@placeholder}}
        @value={{this.topicIds}}
        {{didUpdate this.hydrateSelectedTopics @field.value}}
      />
    </ExpressionWrapper>
  </template>
}
