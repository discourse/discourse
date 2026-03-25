import AppreciationStream from "discourse/components/appreciation-stream";

export default <template>
  <AppreciationStream
    @items={{@model.items}}
    @canLoadMore={{@model.canLoadMore}}
    @lastCursor={{@model.lastCursor}}
    @username={{@model.username}}
    @direction={{@model.direction}}
    @types={{@model.types}}
  />
</template>
