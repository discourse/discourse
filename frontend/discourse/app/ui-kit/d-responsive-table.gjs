import HorizontalScrollSyncWrapper from "discourse/components/horizontal-scroll-sync-wrapper";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

const DResponsiveTable = <template>
  <HorizontalScrollSyncWrapper class="directory-table-container" ...attributes>
    <div
      role="table"
      aria-label={{@ariaLabel}}
      style={{@style}}
      class={{dConcatClass "directory-table" @className}}
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

export default DResponsiveTable;
