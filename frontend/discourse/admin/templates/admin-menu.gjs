import SidebarPanelPage from "discourse/components/sidebar/panel-page";
import { ADMIN_PANEL } from "discourse/lib/sidebar/panels";

export default <template>
  <div class="admin-menu">
    <SidebarPanelPage @panelKey={{ADMIN_PANEL}} />
  </div>
</template>
