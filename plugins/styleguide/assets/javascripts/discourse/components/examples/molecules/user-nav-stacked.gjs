import MobileNav from "discourse/components/mobile-nav";

export default <template>
  <section class="user-navigation">
    <MobileNav
      class="preferences-nav"
      @desktopClass="preferences-list action-list nav-stacked"
    >
      {{#each @navItems key="name" as |navItem|}}
        <li>
          <a
            class={{if navItem.styleGuideActive "active"}}
            href={{navItem.href}}
          >
            {{navItem.displayName}}
          </a>
        </li>
      {{/each}}
    </MobileNav>
  </section>
</template>
