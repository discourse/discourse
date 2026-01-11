import { apiInitializer } from "discourse/lib/api";
import RouteInspector from "../components/route-inspector";
import RouteInspectorToggle from "../components/route-inspector-toggle";

export default apiInitializer((api) => {
  api.renderInOutlet("after-main-outlet", RouteInspector);

  api.headerIcons.add("route-inspector", RouteInspectorToggle, {
    before: "search",
  });
});
