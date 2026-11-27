import { apiInitializer } from "discourse/lib/api";

const ONBOARDING_REPORTS = ["lovelace_onboarding", "lovelace_onboarding_items"];

export default apiInitializer((api) => {
  api.modifyClass(
    "component:admin-report-table",
    (Superclass) =>
      class extends Superclass {
        get showTotalForSample() {
          if (ONBOARDING_REPORTS.includes(this.args.model?.type)) {
            return false;
          }
          return super.showTotalForSample;
        }
      }
  );
});
