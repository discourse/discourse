import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";

const CategoryTitleBefore = <template>
  <PluginOutlet
    @name="category-title-before"
    @outletArgs={{lazyHash category=@category}}
  />
</template>;

export default CategoryTitleBefore;
