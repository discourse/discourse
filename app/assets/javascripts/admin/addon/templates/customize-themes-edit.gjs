import { LinkTo } from "@ember/routing";
import RouteTemplate from "ember-route-template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";
import AdminThemeEditor from "admin/components/admin-theme-editor";

export default RouteTemplate(
  <template>
    <div class="current-style {{if @controller.maximized 'maximized'}}">
      <div class="wrapper">
        <div class="editor-information">
          <DButton
            @title="go_back"
            @action={{@controller.goBack}}
            @icon="chevron-left"
            class="btn-small editor-back-button"
          />

          <span class="editor-theme-name-wrapper">
            {{i18n "admin.customize.theme.edit_css_html"}}
            <LinkTo
              @route={{@controller.showRouteName}}
              @model={{@controller.model.id}}
              @replace={{true}}
              class="editor-theme-name"
            >
              {{@controller.model.name}}
            </LinkTo>
          </span>
        </div>

        <AdminThemeEditor
          @theme={{@controller.model}}
          @editRouteName={{@controller.editRouteName}}
          @currentTargetName={{@controller.currentTargetName}}
          @fieldName={{@controller.fieldName}}
          @fieldAdded={{@controller.fieldAdded}}
          @maximized={{@controller.maximized}}
          @save={{@controller.save}}
          @class="editor-container"
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
);
