import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dNumber from "discourse/ui-kit/helpers/d-number";

const ViewsCell = <template>
  <td class={{dConcatClass "num views topic-list-data" @topic.viewsHeat}}>
    <PluginOutlet
      @name="topic-list-before-view-count"
      @outletArgs={{lazyHash topic=@topic}}
    />
    {{dNumber @topic.views numberKey="views_long"}}
  </td>
</template>;

export default ViewsCell;
