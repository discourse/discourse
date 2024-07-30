import { hash } from "@ember/helper";

const DropdownItem = <template>
  <li class="dropdown-menu__item" ...attributes>{{yield}}</li>
</template>;

const DropdownDivider = <template>
  <li ...attributes><hr class="dropdown-menu__divider" /></li>
</template>;

const DropdownMenu = <template>
  <ul class="dropdown-menu" ...attributes>
    {{yield (hash item=DropdownItem divider=DropdownDivider)}}
  </ul>
</template>;

export default DropdownMenu;
