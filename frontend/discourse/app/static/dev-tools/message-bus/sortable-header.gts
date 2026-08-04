import type { TemplateOnlyComponent } from "@ember/component/template-only";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

export type SortColumn =
  | "channel"
  | "subscribers"
  | "messages"
  | "last-message"
  | "errors"
  | "slowest";

export interface MessageBusSort {
  column: SortColumn;
  asc: boolean;
}

interface SortableHeaderSignature {
  Args: {
    /** Column represented by this heading. */
    column: SortColumn;
    /** Translated label shown in the heading. */
    label: string;
    /** Full name behind an abbreviated label, shown as its tooltip. */
    titleLabel?: string;
    /** Currently active sort configuration. */
    sort: MessageBusSort;
    /** Selects the column or reverses its active direction. */
    onSort: (column: SortColumn) => void;
  };
  Element: HTMLTableCellElement;
}

const SortableHeader: TemplateOnlyComponent<SortableHeaderSignature> =
  <template>
    <th
      class={{dConcatClass (if (eq @sort.column @column) "is-current-sort")}}
      aria-sort={{if
        (eq @sort.column @column)
        (if @sort.asc "ascending" "descending")
        "none"
      }}
      ...attributes
    >
      <button
        type="button"
        title={{if @titleLabel @titleLabel @label}}
        aria-label={{if @titleLabel @titleLabel @label}}
        {{on "click" (fn @onSort @column)}}
      >
        {{@label}}
        {{dIcon
          (if
            (eq @sort.column @column)
            (if @sort.asc "angle-up" "angle-down")
            "angle-up"
          )
        }}
      </button>
    </th>
  </template>;

export default SortableHeader;
