import Component from "@glimmer/component";
import MobileNav from "discourse/components/mobile-nav";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class NavigationStacked extends Component {
  navStackedCode = `<MobileNav
  @desktopClass="preferences-list action-list nav-stacked"
  class="preferences-nav"
>
  {{#each @dummy.navItems as |ni|}}
    <li>
      <a href={{ni.href}} class={{if ni.styleGuideActive "active"}}>
        {{ni.displayName}}
      </a>
    </li>
  {{/each}}
</MobileNav>`;

  userNavStackedCode = `<section class="user-navigation">
  <MobileNav
    @desktopClass="preferences-list action-list nav-stacked"
    class="preferences-nav"
  >
    {{#each @dummy.navItems as |ni|}}
      <li>
        <a href={{ni.href}} class={{if ni.styleGuideActive "active"}}>
          {{ni.displayName}}
        </a>
      </li>
    {{/each}}
  </MobileNav>
</section>`;

  <template>
    <StyleguideExample
      @title=".nav-stacked"
      class="half-size"
      @code={{this.navStackedCode}}
    >
      <MobileNav
        @desktopClass="preferences-list action-list nav-stacked"
        class="preferences-nav"
      >
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
      @title=".user-navigation .nav-stacked"
      class="half-size"
      @code={{this.userNavStackedCode}}
    >
      <section class="user-navigation">
        <MobileNav
          @desktopClass="preferences-list action-list nav-stacked"
          class="preferences-nav"
        >
          {{#each @dummy.navItems as |ni|}}
            <li>
              <a href={{ni.href}} class={{if ni.styleGuideActive "active"}}>
                {{ni.displayName}}
              </a>
            </li>
          {{/each}}
        </MobileNav>
      </section>
    </StyleguideExample>
  </template>
}
