import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import number from "discourse/helpers/number";

const ViewsCell = <template>
  <td class={{concatClass "num views topic-list-data" @topic.viewsHeat}}>
    <PluginOutlet
      @name="topic-list-before-view-count"
      @outletArgs={{lazyHash topic=@topic}}
    />
    {{number @topic.views numberKey="views_long"}}
  </td>
</template>;

export default ViewsCell;
