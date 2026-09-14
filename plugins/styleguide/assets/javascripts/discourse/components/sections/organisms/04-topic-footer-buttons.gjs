import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicFooterButtonsExample from "../../examples/organisms/topic-footer-buttons";
import topicFooterButtonsSource from "../../examples/organisms/topic-footer-buttons?source=file";
import TopicFooterButtonsAnonymousExample from "../../examples/organisms/topic-footer-buttons-anonymous";
import topicFooterButtonsAnonymousSource from "../../examples/organisms/topic-footer-buttons-anonymous?source=file";

export default <template>
  <StyleguideExample
    @code={{topicFooterButtonsSource}}
    @title="<TopicFooterButtons> - logged in"
  >
    <TopicFooterButtonsExample @topic={{@dummy.topic}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{topicFooterButtonsAnonymousSource}}
    @title="<TopicFooterButtons> - anonymous"
  >
    <div class="styleguide-anon">
      <TopicFooterButtonsAnonymousExample />
    </div>
  </StyleguideExample>
</template>
