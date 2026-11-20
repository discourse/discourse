import { apiInitializer } from "discourse/lib/api";
import decorateAiThinking from "../lib/decorate-ai-thinking.js";

export default apiInitializer((api) => {
  api.decorateCookedElement(decorateAiThinking, { id: "ai-thinking-carets" });
});
