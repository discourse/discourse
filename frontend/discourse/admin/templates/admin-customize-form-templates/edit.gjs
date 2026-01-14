import Form from "discourse/admin/components/form-template/form";
import InfoHeader from "discourse/admin/components/form-template/info-header";

export default <template>
  <div class="edit-form-template">
    <InfoHeader />
    <Form @model={{@controller.model}} />
  </div>
</template>
