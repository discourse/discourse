import icon from "discourse-common/helpers/d-icon";

const ActionList = <template>
  {{#if @postNumbers}}
    <div class="post-actions" ...attributes>
      {{icon @icon}}
      {{#each @postNumbers as |postNumber|}}
        <a href="{{@topic.url}}/{{postNumber}}">#{{postNumber}}</a>
      {{/each}}
    </div>
  {{/if}}
</template>;

export default ActionList;
