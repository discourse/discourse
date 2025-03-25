import RouteTemplate from 'ember-route-template'
import InfoHeader from "admin/components/form-template/info-header";
import Form from "admin/components/form-template/form";
export default RouteTemplate(<template><div class="edit-form-template">
  <InfoHeader />
  <Form @model={{@controller.model}} />
</div></template>)