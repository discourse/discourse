import { i18n } from "discourse-i18n";

const SkippedThemeComponents = <template>
  <div class="skipped-theme-components">
    <p>{{i18n "admin.customize.theme.skipped_components" name=@model.name}}</p>
    <ul class="skipped-theme-components__list">
      {{#each @model.components as |skipped|}}
        <li class="skipped-theme-components__item">
          <code>{{skipped.url}}</code>
          {{skipped.error}}
        </li>
      {{/each}}
    </ul>
  </div>
</template>;

export function alertSkippedComponents(dialog, json) {
  if (json.skipped_components?.length) {
    dialog.alert({
      bodyComponent: SkippedThemeComponents,
      bodyComponentModel: {
        name: json.theme.name,
        components: json.skipped_components,
      },
    });
  }
}
