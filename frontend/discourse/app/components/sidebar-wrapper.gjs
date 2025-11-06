import Sidebar from "discourse/components/sidebar";
import bodyClass from "discourse/helpers/body-class";

const SidebarWrapper = <template>
  {{bodyClass "sidebar-enabled"}}

  <div class="sidebar-wrapper">
    {{! empty div allows for animation }}
    {{#if @showSidebar}}
      <Sidebar @toggleSidebar={{@toggleSidebar}} />
    {{/if}}
  </div>
</template>;

export default SidebarWrapper;
