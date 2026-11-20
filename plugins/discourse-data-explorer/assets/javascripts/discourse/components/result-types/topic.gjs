import { trustHTML } from "@ember/template";

const Topic = <template>
  <a href="{{@ctx.baseuri}}/t/{{@ctx.topic.slug}}/{{@ctx.topic.id}}">
    {{trustHTML @ctx.topic.fancy_title}}
  </a>
  ({{@ctx.topic.posts_count}})
</template>;

export default Topic;
