<DPageHeader
  @titleLabel={{i18n "admin.config.search_everything.title"}}
  @descriptionLabel={{i18n "admin.config.search_everything.header_description"}}
  @shouldDisplay={{true}}
>
  <:breadcrumbs>
    <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
    <DBreadcrumbsItem
      @path="/admin/search"
      @label={{i18n "admin.config.search_everything.title"}}
    />
  </:breadcrumbs>
</DPageHeader>

<div class="admin-container admin-config-page__main-area">
  <div class="admin-config-area__full-width">
    <AdminSearch @initialFilter={{this.filter}} />
  </div>
</div>