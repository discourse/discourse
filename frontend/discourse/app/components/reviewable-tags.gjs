import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import dDiscourseTags from "discourse/ui-kit/helpers/d-discourse-tags";

const ReviewableTags = <template>
  {{#if @tags}}
    <div class="list-tags">
      <PluginOutlet
        @name="reviewable-tags-wrapper"
        @outletArgs={{lazyHash topic=@topic tags=@tags}}
      >
        {{dDiscourseTags @topic tags=@tags}}
      </PluginOutlet>
    </div>
  {{/if}}
</template>;

export default ReviewableTags;
