<section class="tag-info">
  {{#if this.tagInfo}}
    <div class="tag-name">
      {{#if this.editing}}
        <div class="edit-tag-wrapper">
          <TextField
            @id="edit-name"
            @value={{readonly this.tagInfo.name}}
            @maxlength={{this.siteSettings.max_tag_length}}
            @input={{with-event-value (fn (mut this.newTagName))}}
            @autofocus="true"
          />

          <Textarea
            id="edit-description"
            @value={{readonly this.tagInfo.descriptionWithNewLines}}
            placeholder={{i18n "tagging.description"}}
            maxlength={{1000}}
            {{on "input" (with-event-value (fn (mut this.newTagDescription)))}}
            autofocus="true"
          />

          <div class="edit-controls">
            {{#unless this.updateDisabled}}
              <DButton
                @action={{action "finishedEditing"}}
                @icon="check"
                @ariaLabel="tagging.save"
                class="btn-primary submit-edit"
              />
            {{/unless}}
            <DButton
              @action={{action "cancelEditing"}}
              @icon="xmark"
              @ariaLabel="cancel"
              class="btn-default cancel-edit"
            />
          </div>
        </div>
      {{else}}
        <div class="tag-name-wrapper">
          {{discourse-tag this.tagInfo.name tagName="div"}}
          {{#if this.canAdminTag}}
            <a
              href
              {{on "click" this.edit}}
              class="edit-tag"
              title={{i18n "tagging.edit_tag"}}
            >{{d-icon "pencil"}}</a>
          {{/if}}
        </div>
        {{#if this.tagInfo.description}}
          <div class="tag-description-wrapper">
            <span>{{html-safe this.tagInfo.description}}</span>
          </div>
        {{/if}}
      {{/if}}
    </div>
    <div class="tag-associations">
      {{~#if this.tagInfo.tag_group_names}}
        {{this.tagGroupsInfo}}
      {{/if~}}
      {{~#if this.tagInfo.categories}}
        {{this.categoriesInfo}}
        <br />
        {{#each this.tagInfo.categories as |category|}}
          {{category-link category}}
        {{/each}}
      {{/if~}}
      {{~#if this.nothingToShow}}
        {{#if this.tagInfo.category_restricted}}
          {{i18n "tagging.category_restricted"}}
        {{else}}
          {{html-safe (i18n "tagging.default_info")}}
          {{#if this.canAdminTag}}
            {{html-safe (i18n "tagging.staff_info" basePath=(base-path))}}
          {{/if}}
        {{/if}}
      {{/if~}}
    </div>
    {{#if this.tagInfo.synonyms}}
      <div class="synonyms-list">
        <h3>{{i18n "tagging.synonyms"}}</h3>
        <div>{{html-safe
            (i18n
              "tagging.synonyms_description" base_tag_name=this.tagInfo.name
            )
          }}</div>
        <div class="tag-list">
          {{#each this.tagInfo.synonyms as |tag|}}
            <div class="tag-box">
              {{discourse-tag tag.id pmOnly=tag.pmOnly tagName="div"}}
              {{#if this.editSynonymsMode}}
                <a
                  href
                  {{on "click" (fn this.unlinkSynonym tag)}}
                  class="unlink-synonym"
                >
                  {{d-icon "link-slash" title="tagging.remove_synonym"}}
                </a>
                <a
                  href
                  {{on "click" (fn this.deleteSynonym tag)}}
                  class="delete-synonym"
                >
                  {{d-icon "trash-can" title="tagging.delete_tag"}}
                </a>
              {{/if}}
            </div>
          {{/each}}
        </div>
      </div>
    {{/if}}
    {{#if this.editSynonymsMode}}
      <section class="add-synonyms field">
        <label for="add-synonyms">{{i18n "tagging.add_synonyms_label"}}</label>
        <div class="add-synonyms__controls">
          <TagChooser
            @id="add-synonyms"
            @tags={{this.newSynonyms}}
            @blockedTags={{array this.tagInfo.name}}
            @everyTag={{true}}
            @excludeSynonyms={{true}}
            @excludeHasSynonyms={{true}}
            @unlimitedTagCount={{true}}
            @allowCreate={{true}}
          />
          {{#if this.newSynonyms}}
            <DButton
              @action={{action "addSynonyms"}}
              @disabled={{this.addSynonymsDisabled}}
              @icon="check"
              class="ok"
            />
          {{/if}}
        </div>
      </section>
    {{/if}}
    {{#if this.canAdminTag}}
      <PluginOutlet
        @name="tag-custom-settings"
        @outletArgs={{hash tag=this.tagInfo}}
        @connectorTagName="section"
      />

      <div class="tag-actions">
        <DButton
          @action={{action "toggleEditControls"}}
          @icon="gear"
          @label="tagging.edit_synonyms"
          id="edit-synonyms"
          class="btn-default"
        />
        {{#if this.canAdminTag}}
          <DButton
            @action={{action "deleteTag"}}
            @icon="trash-can"
            @label="tagging.delete_tag"
            id="delete-tag"
            class="btn-danger delete-tag"
          />
        {{/if}}
      </div>
    {{/if}}
  {{/if}}
  {{#if this.loading}}
    <div>{{i18n "loading"}}</div>
  {{/if}}
</section>