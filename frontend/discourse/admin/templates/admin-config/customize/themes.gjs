import Themes from "discourse/admin/components/admin-config-areas/themes";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import { i18n } from "discourse-i18n";

export default <template>
  <DBreadcrumbsItem
    @label={{i18n "admin.config_areas.themes_and_components.themes.title"}}
    @path="/admin/config/customize/themes"
  />

  <Themes
    @clearParams={{this.clearParams}}
    @repoName={{@controller.model.repoName}}
    @repoUrl={{@controller.model.repoUrl}}
    @themes={{@controller.model.themes}}
  />
</template>
