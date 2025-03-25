import RouteTemplate from "ember-route-template";
import bodyClass from "discourse/helpers/body-class";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import htmlClass from "discourse/helpers/html-class";

export default RouteTemplate(
  <template>
    {{hideApplicationFooter}}
    {{htmlClass "admin-area"}}
    {{bodyClass "admin-interface"}}

    <div class="row">
      <div class="full-width">
        <div class="boxed white admin-content">
          <div class="admin-contents {{@controller.adminContentsClassName}}">
            {{outlet}}
          </div>
        </div>
      </div>
    </div>
  </template>
);
