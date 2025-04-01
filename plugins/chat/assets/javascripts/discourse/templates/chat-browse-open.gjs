import RouteTemplate from "ember-route-template";
import BrowseChannels from "discourse/plugins/chat/discourse/components/browse-channels";

export default RouteTemplate(
  <template><BrowseChannels @currentTab="open" /></template>
);
