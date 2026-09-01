import { concat } from "@ember/helper";
import { trustHTML } from "@ember/template";
import AdminPluginsList from "discourse/admin/components/admin-plugins-list";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DFilterControls from "discourse/ui-kit/d-filter-controls";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="admin-plugins-list-container">

    <DPageHeader
      @descriptionLabel={{trustHTML
        (concat
          (i18n "admin.config.plugins.header_description")
          '<a class="admin-plugins-howto" href="https://meta.discourse.org/t/install-a-plugin/19157">'
          (i18n "admin.plugins.howto")
          "</a>"
        )
      }}
      @hideTabs={{true}}
      @titleLabel={{i18n "admin.config.plugins.title"}}
    >
      <:breadcrumbs>
        <DBreadcrumbsItem @label={{i18n "admin_title"}} @path="/admin" />
        <DBreadcrumbsItem
          @label={{i18n "admin.plugins.title"}}
          @path="/admin/plugins"
        />
      </:breadcrumbs>
    </DPageHeader>

    {{#if @controller.model.length}}
      <DFilterControls
        @array={{@controller.model}}
        @dropdownOptions={{@controller.dropdownOptions}}
        @inputPlaceholder={{i18n "admin.plugins.filters.search_placeholder"}}
        @noResultsMessage={{i18n "admin.plugins.filters.no_results"}}
        @searchableProps={{@controller.searchableProps}}
      >
        <:content as |filteredPlugins|>
          <AdminPluginsList @plugins={{filteredPlugins}} />
        </:content>
      </DFilterControls>
    {{else}}
      <p>{{i18n "admin.plugins.none_installed"}}</p>
    {{/if}}

    <span>
      <PluginOutlet
        @connectorTagName="div"
        @name="admin-below-plugins-index"
        @outletArgs={{lazyHash model=@controller.model}}
      />
    </span>
  </div>
</template>
