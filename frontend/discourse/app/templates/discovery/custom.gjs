import BlockOutlet from "discourse/blocks/block-outlet";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";

export default <template>
  <BlockOutlet @name="homepage-blocks" @outletArgs={{lazyHash model=@model}}>
    <:after as |hasBlocks|>
      <PluginOutlet
        @name="custom-homepage"
        @outletArgs={{lazyHash model=@model hasBlocks=hasBlocks}}
      />
    </:after>
  </BlockOutlet>
</template>
