import { apiInitializer } from "discourse/lib/api";
import AiDsaClassificationSuggestion from "../components/ai-dsa-classification-suggestion.gjs";

export default apiInitializer((api) => {
  api.renderInOutlet(
    "dsa-community-rule-control",
    AiDsaClassificationSuggestion
  );
  api.renderInOutlet("dsa-category-control", AiDsaClassificationSuggestion);
});
