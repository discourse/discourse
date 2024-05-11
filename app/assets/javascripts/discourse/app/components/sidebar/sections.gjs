import AnonymousSections from "./anonymous/sections";
import UserSections from "./user/sections";

const SidebarSections = <template>
  {{#if @currentUser}}
    <UserSections
      @collapsableSections={{@collapsableSections}}
      @panel={{@panel}}
    />
  {{else}}
    <AnonymousSections @collapsableSections={{@collapsableSections}} />
  {{/if}}
</template>;

export default SidebarSections;
