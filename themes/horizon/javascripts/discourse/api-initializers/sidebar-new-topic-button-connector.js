import { apiInitializer } from "discourse/lib/api";
import SidebarNewTopicButton from "../components/sidebar-new-topic-button.gjs";

export default apiInitializer((api) => {
  api.renderInOutlet("before-sidebar-sections", SidebarNewTopicButton);
});
