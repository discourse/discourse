import { apiInitializer } from "discourse/lib/api";
import AiDsaClassificationSuggestion from "../components/ai-dsa-classification-suggestion.gjs";

export default apiInitializer((api) => {
  const siteSettings = api.container.lookup("service:site-settings");

  api.registerValueTransformer("dsa-classification-suggestion", () => {
    if (
      siteSettings.discourse_ai_enabled &&
      siteSettings.ai_dsa_classification_decision_model
    ) {
      return AiDsaClassificationSuggestion;
    }
  });
});
