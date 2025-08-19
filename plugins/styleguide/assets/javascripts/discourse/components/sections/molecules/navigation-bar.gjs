import MobileNav from "discourse/components/mobile-nav";
import NavigationBar from "discourse/components/navigation-bar";
import GroupDropdown from "select-kit/components/group-dropdown";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

const NavigationBarMolecule = <template>
  <StyleguideExample @title="<NavigationBar>">
    <NavigationBar @navItems={{@dummy.navItems}} @filterMode="latest" />
  </StyleguideExample>

  <StyleguideExample @title=".user-main .nav-pills">
    <MobileNav @desktopClass="nav nav-pills user-nav" class="main-nav">
      {{#each @dummy.navItems as |ni|}}
        <li>
          <a href={{ni.href}} class={{if ni.styleGuideActive "active"}}>
            {{ni.displayName}}
          </a>
        </li>
      {{/each}}
    </MobileNav>
  </StyleguideExample>

  <StyleguideExample @title="group page <NavigationBar>">
    <MobileNav @desktopClass="nav nav-pills" class="group-nav">
      <li class="group-dropdown">
        <GroupDropdown @groups={{@dummy.groupNames}} @value="staff" />
      </li>

      {{#each @dummy.navItems as |ni|}}
        <li>
          <a href={{ni.href}} class={{if ni.styleGuideActive "active"}}>
            {{ni.displayName}}
          </a>
        </li>
      {{/each}}
    </MobileNav>
  </StyleguideExample>
</template>;

export default NavigationBarMolecule;
