import { apiInitializer } from "discourse/lib/api";
import SidebarNewTopicButton from "../components/sidebar-new-topic-button";

export default apiInitializer((api) => {
  api.renderInOutlet("before-sidebar-sections", SidebarNewTopicButton);
});
