import { apiInitializer } from "discourse/lib/api";
import AiSharingActivityTabs from "../components/ai-sharing-activity-tabs.gjs";

export default apiInitializer((api) => {
  api.renderInOutlet("user-activity-bottom", AiSharingActivityTabs);

  const displayed = ({ siteSettings, currentUser, user }) =>
    siteSettings.discourse_ai_enabled &&
    currentUser &&
    user &&
    Number.isInteger(user.id) &&
    user.id > 0 &&
    (currentUser.admin || currentUser.id === user.id);

  api.addUserNavSidebarLink("activity", {
    name: "activity-shared-ai-artifacts",
    route: "userActivity.sharedAiArtifacts",
    label: "discourse_ai.ai_artifact.shared_artifacts",
    icon: "code",
    displayed,
  });

  api.addUserNavSidebarLink("activity", {
    name: "activity-shared-ai-conversations",
    route: "userActivity.sharedAiConversations",
    label: "discourse_ai.shared_ai_conversations.title",
    icon: "comment",
    displayed,
  });
});
