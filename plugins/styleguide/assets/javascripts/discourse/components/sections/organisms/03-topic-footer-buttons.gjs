import DButton from "discourse/components/d-button";
import TopicFooterButtons from "discourse/components/topic-footer-buttons";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const TopicFooterButtonsOrganism = <template>
  <StyleguideExample @title="<TopicFooterButtons> - logged in">
    <TopicFooterButtons @topic={{@dummy.topic}} />
  </StyleguideExample>

  <StyleguideExample @title="<TopicFooterButtons> - anonymous">
    <div id="topic-footer-buttons">
      <DButton
        @icon="reply"
        @label="topic.reply.title"
        class="btn-primary pull-right"
      />
    </div>
  </StyleguideExample>
</template>;

export default TopicFooterButtonsOrganism;
