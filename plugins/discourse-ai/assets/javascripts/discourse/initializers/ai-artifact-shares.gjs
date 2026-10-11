import { apiInitializer } from "discourse/lib/api";
import AiSharingActivityTabs from "../components/ai-sharing-activity-tabs";

export default apiInitializer((api) => {
  api.renderInOutlet("user-activity-bottom", AiSharingActivityTabs);
});
