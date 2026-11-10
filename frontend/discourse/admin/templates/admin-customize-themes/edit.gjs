import AdminThemeEditor from "discourse/admin/components/admin-theme-editor";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
  <div class="current-style {{if @controller.maximized 'maximized'}}">
    <div class="wrapper">
      <AdminThemeEditor
        class="editor-container"
        @currentTargetName={{@controller.currentTargetName}}
        @editRouteName={{@controller.editRouteName}}
        @fieldAdded={{@controller.fieldAdded}}
        @fieldName={{@controller.fieldName}}
        @goBack={{@controller.goBack}}
        @maximized={{@controller.maximized}}
        @save={{@controller.save}}
        @showRouteName={{@controller.showRouteName}}
        @theme={{@controller.model}}
      />

      <div class="admin-footer">
        <div class="status-actions">
          {{#unless @controller.model.changed}}
            <a
              class="preview-link"
              href={{@controller.previewUrl}}
              rel="noopener noreferrer"
              target="_blank"
              title={{i18n "admin.customize.explain_preview"}}
            >
              {{i18n "admin.customize.preview"}}
            </a>
          {{/unless}}
        </div>

        <div class="buttons">
          <DButton
            class="btn-primary save-theme"
            @action={{@controller.save}}
            @disabled={{@controller.saveDisabled}}
            @translatedLabel={{@controller.saveButtonText}}
          />
        </div>
      </div>
    </div>
  </div>
</template>
