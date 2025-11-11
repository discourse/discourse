import HorizontalScrollSyncWrapper from "discourse/components/horizontal-scroll-sync-wrapper";
import concatClass from "discourse/helpers/concat-class";

const ResponsiveTable = <template>
  <HorizontalScrollSyncWrapper class="directory-table-container" ...attributes>
    <div
      role="table"
      aria-label={{@ariaLabel}}
      style={{@style}}
      class={{concatClass "directory-table" @className}}
    >
      <div class="directory-table__header">
        {{yield to="header"}}
      </div>

      <div class="directory-table__body">
        {{yield to="body"}}
      </div>
    </div>
  </HorizontalScrollSyncWrapper>
</template>;

export default ResponsiveTable;
