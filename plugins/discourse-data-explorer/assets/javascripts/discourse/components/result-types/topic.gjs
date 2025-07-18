import htmlSafe from "discourse/helpers/html-safe";

const Topic = <template>
  {{#if @ctx.topic}}
    <a href="{{@ctx.baseuri}}/t/{{@ctx.topic.slug}}/{{@ctx.topic.id}}">
      {{htmlSafe @ctx.topic.fancy_title}}
    </a>
    ({{@ctx.topic.posts_count}})
  {{else}}
    <a href="{{@ctx.baseuri}}/t/{{@ctx.id}}">{{@ctx.id}}</a>
  {{/if}}
</template>;

export default Topic;
