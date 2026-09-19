import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-problem-checks admin-config-page">
    <DPageHeader
      @descriptionLabel={{i18n
        "admin.config.problem_checks.header_description"
      }}
      @titleLabel={{i18n "admin.config.problem_checks.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.config.problem_checks.title"}}
          @path="/admin/problem-checks"
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      {{outlet}}
    </div>
  </div>
</template>
