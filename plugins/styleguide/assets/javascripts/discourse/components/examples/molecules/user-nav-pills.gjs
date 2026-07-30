import MobileNav from "discourse/components/mobile-nav";

export default <template>
  <MobileNav @desktopClass="nav nav-pills user-nav" class="main-nav">
    {{#each @navItems key="name" as |navItem|}}
      <li>
        <a href={{navItem.href}} class={{if navItem.styleGuideActive "active"}}>
          {{navItem.displayName}}
        </a>
      </li>
    {{/each}}
  </MobileNav>
</template>
