import AnonymousSections from "./anonymous/sections.gjs";
import UserSections from "./user/sections.gjs";

const SidebarSections = <template>
  {{#if @currentUser}}
    <UserSections
      @collapsableSections={{@collapsableSections}}
      @enableLinkDrop={{@enableLinkDrop}}
      @hideApiSections={{@hideApiSections}}
      @panel={{@panel}}
      @toggleNavigationMenu={{@toggleNavigationMenu}}
    />
  {{else}}
    <AnonymousSections
      @collapsableSections={{@collapsableSections}}
      @toggleNavigationMenu={{@toggleNavigationMenu}}
    />
  {{/if}}
</template>;

export default SidebarSections;
