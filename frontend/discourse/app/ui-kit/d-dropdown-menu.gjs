import { hash } from "@ember/helper";

const DropdownItem = <template>
  <li class="dropdown-menu__item" ...attributes>{{yield}}</li>
</template>;

const DropdownDivider = <template>
  <li ...attributes><hr class="dropdown-menu__divider" /></li>
</template>;

const DropdownSubheader = <template>
  <li class="dropdown-menu__subheader" ...attributes>{{yield}}</li>
</template>;

const DDropdownMenu = <template>
  <ul class="dropdown-menu" ...attributes>
    {{yield
      (hash
        item=DropdownItem divider=DropdownDivider subheader=DropdownSubheader
      )
    }}
  </ul>
</template>;

export default DDropdownMenu;
