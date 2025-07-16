import { apiInitializer } from "discourse/lib/api";
import discourseComputed from "discourse/lib/decorators";
import { findAll } from "discourse/models/login-method";

export default apiInitializer("0.8", (api) => {
  // LTI login must be initiated by the IdP
  // Hide the LTI login button on the client side:
  api.modifyClass(
    "component:login-buttons",
    (Superclass) =>
      class extends Superclass {
        @discourseComputed
        buttons() {
          return super.buttons.filter((m) => m.name !== "lti");
        }
      }
  );

  // Connection is possible, but cannot be initiated
  // by Discourse. It must be initiated by the IdP.
  // Hide the button to avoid confusion:
  const lti = findAll().find((p) => p.name === "lti");
  if (lti) {
    lti.can_connect = false;
  }
});
