import RouteTemplate from "ember-route-template";
import BackButton from "discourse/components/back-button";
import AdminUserFieldsForm from "admin/components/admin-user-fields-form";

export default RouteTemplate(
  <template>
    <BackButton
      @route="adminUserFields.index"
      @label="admin.user_fields.back"
    />
    <div class="admin-config-area user-field">
      <div class="admin-config-area__primary-content">
        <div class="admin-config-area-card">
          <AdminUserFieldsForm @userField={{@controller.model}} />
        </div>
      </div>
    </div>
  </template>
);
