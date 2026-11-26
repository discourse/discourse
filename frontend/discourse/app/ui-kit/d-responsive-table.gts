import type { TOC } from "@ember/component/template-only";
import type { TrustedHTML } from "@ember/template";
import type { ComponentLike } from "@glint/template";
import HorizontalScrollSyncWrapperUntyped from "discourse/components/horizontal-scroll-sync-wrapper";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

/**
 * TODO(typescript-pending): drop once HorizontalScrollSyncWrapper is authored in .gts
 * with a real Signature, then import it directly.
 */
const HorizontalScrollSyncWrapper =
  HorizontalScrollSyncWrapperUntyped as unknown as ComponentLike<{
    Element: HTMLDivElement;
    Blocks: { default: [] };
  }>;

interface DResponsiveTableSignature {
  Args: {
    /** The accessible name of the table. */
    ariaLabel?: string;

    /** Classes added to the table, next to `directory-table`. */
    className?: string;

    /** Inline styles for the table, such as its `grid-template-columns`. */
    style?: TrustedHTML;
  };

  Element: HTMLDivElement;

  Blocks: {
    /** The header row. */
    header: [];

    /** The table rows. */
    body: [];
  };
}

const DResponsiveTable: TOC<DResponsiveTableSignature> = <template>
  <HorizontalScrollSyncWrapper class="directory-table-container" ...attributes>
    <div
      aria-label={{@ariaLabel}}
      class={{dConcatClass "directory-table" @className}}
      role="table"
      style={{@style}}
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
