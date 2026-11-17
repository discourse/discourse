import MobileNav from "discourse/components/mobile-nav";
import GroupDropdown from "discourse/select-kit/components/group-dropdown";

const GROUPS = ["staff", "lounge", "admin"];

export default <template>
  <MobileNav class="group-nav" @desktopClass="nav nav-pills">
    <li class="group-dropdown">
      <GroupDropdown @groups={{GROUPS}} @value="staff" />
    </li>

    {{#each @navItems key="name" as |navItem|}}
      <li>
        <a class={{if navItem.styleGuideActive "active"}} href={{navItem.href}}>
          {{navItem.displayName}}
        </a>
      </li>
    {{/each}}
  </MobileNav>
</template>
