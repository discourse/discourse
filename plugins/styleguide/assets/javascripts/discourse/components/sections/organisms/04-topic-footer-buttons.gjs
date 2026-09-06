import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicFooterButtonsExample from "../../examples/organisms/topic-footer-buttons";
import topicFooterButtonsSource from "../../examples/organisms/topic-footer-buttons?source=file";
import TopicFooterButtonsAnonymousExample from "../../examples/organisms/topic-footer-buttons-anonymous";
import topicFooterButtonsAnonymousSource from "../../examples/organisms/topic-footer-buttons-anonymous?source=file";

export default <template>
  <StyleguideExample
    @title="<TopicFooterButtons> - logged in"
    @code={{topicFooterButtonsSource}}
  >
    <TopicFooterButtonsExample @topic={{@dummy.topic}} />
  </StyleguideExample>

  <StyleguideExample
    @title="<TopicFooterButtons> - anonymous"
    @code={{topicFooterButtonsAnonymousSource}}
  >
    <div class="styleguide-anon">
      <TopicFooterButtonsAnonymousExample />
    </div>
  </StyleguideExample>
</template>
