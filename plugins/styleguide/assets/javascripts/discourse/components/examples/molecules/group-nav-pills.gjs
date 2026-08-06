import MobileNav from "discourse/components/mobile-nav";
import GroupDropdown from "discourse/select-kit/components/group-dropdown";

const GROUPS = ["staff", "lounge", "admin"];

export default <template>
  <MobileNav @desktopClass="nav nav-pills" class="group-nav">
    <li class="group-dropdown">
      <GroupDropdown @groups={{GROUPS}} @value="staff" />
    </li>

    {{#each @navItems key="name" as |navItem|}}
      <li>
        <a href={{navItem.href}} class={{if navItem.styleGuideActive "active"}}>
          {{navItem.displayName}}
        </a>
      </li>
    {{/each}}
  </MobileNav>
</template>
