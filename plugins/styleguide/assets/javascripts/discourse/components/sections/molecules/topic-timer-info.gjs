import Component from "@glimmer/component";
import TopicTimerInfo from "discourse/components/topic-timer-info";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class TopicTimerInfoMolecule extends Component {
  topicTimerInfoCode = `<TopicTimerInfo @statusType="reminder" @executeAt={{@dummy.soon}} />`;

  <template>
    <StyleguideExample
      @title="<TopicTimerInfo>"
      @code={{this.topicTimerInfoCode}}
    >
      <TopicTimerInfo @statusType="reminder" @executeAt={{@dummy.soon}} />
    </StyleguideExample>
  </template>
}
