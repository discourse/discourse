import { buildTagRoute } from "discourse/routes/tag/show";

// Route for /tag/none - shows topics without any tags
export default class extends buildTagRoute() {
  controllerName = "discovery/list";
}
