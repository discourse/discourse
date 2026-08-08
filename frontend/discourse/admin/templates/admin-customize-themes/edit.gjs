import AdminThemeEditor from "discourse/admin/components/admin-theme-editor";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="current-style {{if @controller.maximized 'maximized'}}">
    <div class="wrapper">
      <AdminThemeEditor
        @theme={{@controller.model}}
        @editRouteName={{@controller.editRouteName}}
        @showRouteName={{@controller.showRouteName}}
        @currentTargetName={{@controller.currentTargetName}}
        @fieldName={{@controller.fieldName}}
        @fieldAdded={{@controller.fieldAdded}}
        @maximized={{@controller.maximized}}
        @goBack={{@controller.goBack}}
        @save={{@controller.save}}
        class="editor-container"
      />

      <div class="admin-footer">
        <div class="status-actions">
          {{#unless @controller.model.changed}}
            <a
              href={{@controller.previewUrl}}
              rel="noopener noreferrer"
              title={{i18n "admin.customize.explain_preview"}}
              class="preview-link"
              target="_blank"
            >
              {{i18n "admin.customize.preview"}}
            </a>
          {{/unless}}
        </div>

        <div class="buttons">
          <DButton
            @action={{@controller.save}}
            @disabled={{@controller.saveDisabled}}
            @translatedLabel={{@controller.saveButtonText}}
            class="btn-primary save-theme"
          />
        </div>
      </div>
    </div>
  </div>
</template>
