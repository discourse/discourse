import BasicTopicList from "discourse/components/basic-topic-list";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const BasicTopicListOrganism = <template>
  <StyleguideExample @title="<BasicTopicList>" class="half-size">
    <BasicTopicList @topics={{@dummy.topics}} />
  </StyleguideExample>
</template>;

export default BasicTopicListOrganism;
