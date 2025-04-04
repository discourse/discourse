import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import TopicFooterButtons from "discourse/components/topic-footer-buttons";
import DButton from "discourse/components/d-button";
const 03TopicFooterButtons = <template><StyleguideExample @title="<TopicFooterButtons> - logged in">
  <TopicFooterButtons @topic={{@dummy.topic}} />
</StyleguideExample>

<StyleguideExample @title="<TopicFooterButtons> - anonymous">
  <div id="topic-footer-buttons">
    <DButton @icon="reply" @label="topic.reply.title" class="btn-primary pull-right" />
  </div>
</StyleguideExample></template>;
export default 03TopicFooterButtons;