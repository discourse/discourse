import { apiInitializer } from "discourse/lib/api";
import SidebarNewTopicButton from "../components/sidebar-new-topic-button";

export default apiInitializer("1.8.0", (api) => {
  api.renderInOutlet("before-sidebar-sections", SidebarNewTopicButton);
});
