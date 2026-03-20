import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";

const ReviewableTags = <template>
  {{#if @tags}}
    <div class="list-tags">
      {{dDiscourseTags @topic tags=@tags}}
    </div>
  {{/if}}
</template>;

export default ReviewableTags;
