import bodyClass from "discourse/helpers/body-class";

const AddTopicStatusClasses = <template>
  {{#if @topic.invisible}}
    {{bodyClass "topic-status-unlisted"}}
  {{/if}}
  {{#if @topic.pinned}}
    {{bodyClass "topic-status-pinned"}}
  {{/if}}
  {{#if @topic.unpinned}}
    {{bodyClass "topic-status-unpinned"}}
  {{/if}}
</template>;

export default AddTopicStatusClasses;
