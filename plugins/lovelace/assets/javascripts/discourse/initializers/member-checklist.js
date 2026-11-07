import { apiInitializer } from "discourse/lib/api";
import MemberChecklist from "../components/member-checklist.gjs";

export default apiInitializer((api) => {
  api.renderInOutlet("above-main-container", MemberChecklist);
});
