import MobileNav from "discourse/components/mobile-nav";

export default <template>
  <MobileNav class="main-nav" @desktopClass="nav nav-pills user-nav">
    {{#each @navItems key="name" as |navItem|}}
      <li>
        <a class={{if navItem.styleGuideActive "active"}} href={{navItem.href}}>
          {{navItem.displayName}}
        </a>
      </li>
    {{/each}}
  </MobileNav>
</template>
