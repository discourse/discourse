import type { TOC } from "@ember/component/template-only";
import { hash } from "@ember/helper";

interface DropdownItemSignature {
  Element: HTMLLIElement;
  Blocks: {
    /** The item's content, usually a button or link. */
    default: [];
  };
}

interface DropdownDividerSignature {
  Element: HTMLLIElement;
}

interface DropdownSubheaderSignature {
  Element: HTMLLIElement;
  Blocks: {
    /** The heading text for the group of items that follows. */
    default: [];
  };
}

const DropdownItem: TOC<DropdownItemSignature> = <template>
  <li class="dropdown-menu__item" ...attributes>{{yield}}</li>
</template>;

const DropdownDivider: TOC<DropdownDividerSignature> = <template>
  <li ...attributes><hr class="dropdown-menu__divider" /></li>
</template>;

const DropdownSubheader: TOC<DropdownSubheaderSignature> = <template>
  <li class="dropdown-menu__subheader" ...attributes>{{yield}}</li>
</template>;

interface DDropdownMenuSignature {
  Element: HTMLUListElement;
  Blocks: {
    /** The menu's entries, built from the yielded parts. */
    default: [
      /** The parts a menu is built from, each rendering one list item. */
      dropdown: {
        /** A list item holding one entry of the menu. */
        item: typeof DropdownItem;
        /** A list item holding a horizontal rule between groups of items. */
        divider: typeof DropdownDivider;
        /** A list item holding a heading for the items that follow it. */
        subheader: typeof DropdownSubheader;
      },
    ];
  };
}

/**
 * A list-shaped dropdown menu. It yields the parts its entries are built from,
 * so the markup a menu is made of stays consistent across consumers.
 */
const DDropdownMenu: TOC<DDropdownMenuSignature> = <template>
  <ul class="dropdown-menu" ...attributes>
    {{yield
      (hash
        item=DropdownItem divider=DropdownDivider subheader=DropdownSubheader
      )
    }}
  </ul>
</template>;

export default DDropdownMenu;
