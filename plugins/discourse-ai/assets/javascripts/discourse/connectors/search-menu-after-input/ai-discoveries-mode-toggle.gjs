import Component from "@glimmer/component";
import AiDiscoveriesModeToggle from "../../components/ai-discoveries-mode-toggle";

export default class AiDiscoveriesModeToggleConnector extends Component {
  static shouldRender(args, { currentUser, siteSettings }) {
    return (
      args?.location === "welcome-banner" &&
      siteSettings.ai_discover_enabled &&
      siteSettings.ai_discover_agent &&
      currentUser?.can_use_ai_discover_agent &&
      currentUser?.user_option?.ai_search_discoveries
    );
  }

  <template>
    <AiDiscoveriesModeToggle @submitSearch={{@outletArgs.triggerSearch}} />
  </template>
}
