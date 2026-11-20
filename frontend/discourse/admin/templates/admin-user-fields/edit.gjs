import AdminUserFieldsForm from "discourse/admin/components/admin-user-fields-form";
import BackButton from "discourse/components/back-button";

export default <template>
  <BackButton @label="admin.user_fields.back" @route="adminUserFields.index" />
  <div class="admin-config-area user-field">
    <div class="admin-config-area__primary-content">
      <div class="admin-config-area-card">
        <AdminUserFieldsForm @userField={{@controller.model}} />
      </div>
    </div>
  </div>
</template>
