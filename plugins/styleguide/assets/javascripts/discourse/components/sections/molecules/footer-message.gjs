import Component from "@glimmer/component";
import FooterMessage from "discourse/components/footer-message";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class FooterMessageMolecule extends Component {
  defaultCode = `<FooterMessage
  @education={{@dummy.sentence}}
  @message={{@dummy.short_sentence}}
/>`;

  latestCode = `<FooterMessage
  @education={{@dummy.sentence}}
  @message={{@dummy.short_sentence}}
  @latest={{true}}
  @canCreateTopicOnCategory={{true}}
  @createTopic={{@dummyAction}}
/>`;

  topCode = `<FooterMessage
  @education={{@dummy.sentence}}
  @message={{@dummy.short_sentence}}
  @top={{true}}
  @changePeriod={{@dummyAction}}
/>`;

  <template>
    <StyleguideExample
      @title="<FooterMessage> - default"
      @code={{this.defaultCode}}
    >
      <FooterMessage
        @education={{@dummy.sentence}}
        @message={{@dummy.short_sentence}}
      />
    </StyleguideExample>

    <StyleguideExample
      @title="<FooterMessage> - latest"
      @code={{this.latestCode}}
    >
      <FooterMessage
        @education={{@dummy.sentence}}
        @message={{@dummy.short_sentence}}
        @latest={{true}}
        @canCreateTopicOnCategory={{true}}
        @createTopic={{@dummyAction}}
      />
    </StyleguideExample>

    <StyleguideExample @title="<FooterMessage> - top" @code={{this.topCode}}>
      <FooterMessage
        @education={{@dummy.sentence}}
        @message={{@dummy.short_sentence}}
        @top={{true}}
        @changePeriod={{@dummyAction}}
      />
    </StyleguideExample>
  </template>
}
