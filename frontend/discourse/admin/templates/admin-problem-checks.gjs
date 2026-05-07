import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-problem-checks admin-config-page">
    <DPageHeader
      @titleLabel={{i18n "admin.config.problem_checks.title"}}
      @descriptionLabel={{i18n
        "admin.config.problem_checks.header_description"
      }}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @path="/admin" @label={{i18n "admin_title"}} />
        <DBreadcrumbsItem
          @path="/admin/problem-checks"
          @label={{i18n "admin.config.problem_checks.title"}}
        />
      </:breadcrumbs>
    </DPageHeader>

    <div class="admin-container admin-config-page__main-area">
      {{outlet}}
    </div>
  </div>
</template>
