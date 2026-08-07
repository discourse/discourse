import MobileNav from "discourse/components/mobile-nav";

export default <template>
  <section class="user-navigation">
    <MobileNav
      @desktopClass="preferences-list action-list nav-stacked"
      class="preferences-nav"
    >
      {{#each @navItems key="name" as |navItem|}}
        <li>
          <a
            href={{navItem.href}}
            class={{if navItem.styleGuideActive "active"}}
          >
            {{navItem.displayName}}
          </a>
        </li>
      {{/each}}
    </MobileNav>
  </section>
</template>
