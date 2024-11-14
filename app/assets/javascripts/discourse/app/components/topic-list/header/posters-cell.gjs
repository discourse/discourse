import TopicListHeaderColumn from "discourse/components/topic-list/topic-list-header-column";
import i18n from "discourse-common/helpers/i18n";

const PostersCell = <template>
  {{#if @showPosters}}
    <TopicListHeaderColumn
      @order="posters"
      @activeOrder={{@activeOrder}}
      @changeSort={{@changeSort}}
      @ascending={{@ascending}}
      @name="posters"
      @screenreaderOnly={{true}}
      aria-label={{i18n "category.sort_options.posters"}}
    />
  {{/if}}
</template>;

export default PostersCell;
