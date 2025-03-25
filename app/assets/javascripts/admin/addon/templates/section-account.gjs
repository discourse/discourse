<DPageHeader
  @titleLabel={{i18n "admin.config_sections.account.title"}}
  @hideTabs={{true}}
>
  <:breadcrumbs>
    <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
    <DBreadcrumbsItem
      @path="/admin/section/account"
      @label={{i18n "admin.config_sections.account.title"}}
    />
  </:breadcrumbs>
</DPageHeader>

<AdminSectionLandingWrapper>
  <AdminSectionLandingItem
    @icon="box-archive"
    @titleLabel="admin.config.backups.title"
    @descriptionLabel="admin.config.backups.header_description"
    @titleRoute="admin.backups"
  />
  <AdminSectionLandingItem
    @icon="gift"
    @titleLabel="admin.config.whats_new.title"
    @descriptionLabel="admin.config.whats_new.header_description"
    @titleRoute="admin.whatsNew"
  />
</AdminSectionLandingWrapper>