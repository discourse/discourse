import Component from "@glimmer/component";
import DNavItem from "discourse/ui-kit/d-nav-item";

export default class LayoutsTab extends Component {
  static shouldRender(_args, { currentUser, siteSettings }) {
    return !!currentUser?.admin && !!siteSettings.wireframe_enabled;
  }

  <template>
    <DNavItem
      @label="wireframe.admin.designs.tab"
      @route="adminConfig.customize.layouts"
    />
  </template>
}
