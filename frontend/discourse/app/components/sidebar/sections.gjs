import AnonymousSections from "./anonymous/sections";
import UserSections from "./user/sections";

const SidebarSections = <template>
  {{#if @currentUser}}
    <UserSections
      @collapsableSections={{@collapsableSections}}
      @panel={{@panel}}
      @hideApiSections={{@hideApiSections}}
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
