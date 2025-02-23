import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";

const CategoryTitleBefore = <template>
  <PluginOutlet
    @name="category-title-before"
    @outletArgs={{hash category=@category}}
  />
</template>;

export default CategoryTitleBefore;
