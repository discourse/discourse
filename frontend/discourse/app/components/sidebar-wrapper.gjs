import Sidebar from "discourse/components/sidebar";

const SidebarWrapper = <template>
  <div class="sidebar-wrapper">
    {{! empty div allows for animation }}
    {{#if @showSidebar}}
      <Sidebar @toggleSidebar={{@toggleSidebar}} />
    {{/if}}
  </div>
</template>;

export default SidebarWrapper;
