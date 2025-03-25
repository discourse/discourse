<BackButton @route="adminUserFields.index" @label="admin.user_fields.back" />
<div class="admin-config-area user-field">
  <div class="admin-config-area__primary-content">
    <div class="admin-config-area-card">
      <AdminUserFieldsForm @userField={{this.model}} />
    </div>
  </div>
</div>