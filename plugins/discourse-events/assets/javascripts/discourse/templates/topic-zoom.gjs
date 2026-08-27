import hideApplicationSidebar from "discourse/helpers/hide-application-sidebar";
import LivestreamZoomPage from "../components/livestream/zoom-page";

export default <template>
  {{hideApplicationSidebar}}
  <LivestreamZoomPage @topic={{@model}} />
</template>
