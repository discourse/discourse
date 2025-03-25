<DPageHeader
  @titleLabel={{i18n "admin.config.email.title"}}
  @descriptionLabel={{i18n "admin.config.email.header_description"}}
  @shouldDisplay={{true}}
>
  <:breadcrumbs>
    <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
    <DBreadcrumbsItem
      @path="/admin/email"
      @label={{i18n "admin.config.email.title"}}
    />
  </:breadcrumbs>
  <:tabs>
    <NavItem @route="adminEmail.index" @label="settings" />
    <NavItem
      @route="adminEmail.previewDigest"
      @label="admin.config.email.sub_pages.preview_summary.title"
    />
    <NavItem
      @route="adminEmail.advancedTest"
      @label="admin.config.email.sub_pages.advanced_test.title"
    />
    <NavItem
      @route="adminEmailTemplates"
      @label="admin.config.email.sub_pages.templates.title"
    />
    <NavItem
      @route="adminEmail.sent"
      @label="admin.config.email.sub_pages.sent.title"
    />
    <NavItem
      @route="adminEmail.skipped"
      @label="admin.config.email.sub_pages.skipped.title"
    />
    <NavItem
      @route="adminEmail.bounced"
      @label="admin.config.email.sub_pages.bounced.title"
    />
    <NavItem
      @route="adminEmail.received"
      @label="admin.config.email.sub_pages.received.title"
    />
    <NavItem
      @route="adminEmail.rejected"
      @label="admin.config.email.sub_pages.rejected.title"
    />
  </:tabs>
</DPageHeader>

<div class="admin-container">
  {{outlet}}
</div>