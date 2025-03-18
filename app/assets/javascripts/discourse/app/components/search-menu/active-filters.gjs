import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";

export default class ActiveFilters extends Component {
  @service search;

  <template>
    {{#if this.search.inTopicContext}}
      <DButton
        @icon="xmark"
        @label="search.in_this_topic"
        @title="search.in_this_topic_tooltip"
        @action={{fn (mut this.search.inTopicContext) false}}
        class="btn-small search-context"
        data-test-button="search-in-this-topic"
      />
    {{else if @inPMInboxContext}}
      <DButton
        @icon="xmark"
        @label="search.in_messages"
        @title="search.in_messages_tooltip"
        @action={{@clearPMInboxContext}}
        class="btn-small search-context"
        data-test-button="search-in-messages"
      />
    {{/if}}
  </template>
}
