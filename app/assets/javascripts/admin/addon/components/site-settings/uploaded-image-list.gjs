<DButton
  @label="admin.site_settings.uploaded_image_list.label"
  @action={{fn
    this.showUploadModal
    (hash value=this.value setting=this.setting)
  }}
/>