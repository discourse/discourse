import Component from "@glimmer/component";
import MobileNav from "discourse/components/mobile-nav";
import NavigationBar from "discourse/components/navigation-bar";
import GroupDropdown from "discourse/select-kit/components/group-dropdown";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class NavigationBarMolecule extends Component {
  navigationBarCode = `<NavigationBar @navItems={{@dummy.navItems}} @filterMode="latest" />`;

  userNavCode = `<MobileNav @desktopClass="nav nav-pills user-nav" class="main-nav">
  {{#each @dummy.navItems as |ni|}}
    <li>
      <a href={{ni.href}} class={{if ni.styleGuideActive "active"}}>
        {{ni.displayName}}
      </a>
    </li>
  {{/each}}
</MobileNav>`;

  groupNavCode = `<MobileNav @desktopClass="nav nav-pills" class="group-nav">
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
</MobileNav>`;

  <template>
    <StyleguideExample
      @title="<NavigationBar>"
      @code={{this.navigationBarCode}}
    >
      <NavigationBar @navItems={{@dummy.navItems}} @filterMode="latest" />
    </StyleguideExample>

    <StyleguideExample
      @title=".user-main .nav-pills"
      @code={{this.userNavCode}}
    >
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

    <StyleguideExample
      @title="group page <NavigationBar>"
      @code={{this.groupNavCode}}
    >
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
  </template>
}
