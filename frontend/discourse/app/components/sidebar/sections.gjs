import AnonymousSections from "./anonymous/sections";
import UserSections from "./user/sections";

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
