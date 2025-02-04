<section class="group-name">
  <label>{{i18n "tagging.groups.name_placeholder"}}</label>
  <div><TextField @value={{this.buffered.name}} /></div>
</section>

<section class="group-tags-list">
  <label>{{i18n "tagging.groups.tags_label"}}</label><br />
  <TagChooser
    @tags={{this.buffered.tag_names}}
    @everyTag={{true}}
    @unlimitedTagCount={{true}}
    @excludeSynonyms={{true}}
    @options={{hash
      allowAny=true
      filterPlaceholder="tagging.groups.tags_placeholder"
    }}
  />
</section>

<section class="parent-tag-section">
  <label>{{i18n "tagging.groups.parent_tag_label"}}</label>
  <div>
    <TagChooser
      @tags={{this.buffered.parent_tag_name}}
      @everyTag={{true}}
      @excludeSynonyms={{true}}
      @options={{hash
        allowAny=true
        filterPlaceholder="tagging.groups.parent_tag_placeholder"
        maximum=1
      }}
    />
  </div>
  <div class="description">{{i18n
      "tagging.groups.parent_tag_description"
    }}</div>
</section>

<section class="group-one-per-topic">
  <label>
    <Input
      @type="checkbox"
      @checked={{this.buffered.one_per_topic}}
      name="onepertopic"
    />
    {{i18n "tagging.groups.one_per_topic_label"}}
  </label>
</section>

<section class="group-visibility">
  <div class="group-visibility-option">
    <RadioButton
      @name="tag-permissions-choice"
      @value="public"
      @id="public-permission"
      @selection={{this.buffered.permissionName}}
      class="tag-permissions-choice"
    />

    <label class="radio" for="public-permission">
      {{i18n "tagging.groups.everyone_can_use"}}
    </label>
  </div>
  <div class="group-visibility-option">
    <RadioButton
      @name="tag-permissions-choice"
      @value="visible"
      @id="visible-permission"
      @selection={{this.buffered.permissionName}}
      class="tag-permissions-choice"
    />

    <label class="radio" for="visible-permission">
      {{i18n "tagging.groups.usable_only_by_groups"}}
    </label>

    <div class="group-access-control">
      <GroupChooser
        @content={{this.allGroups}}
        @value={{this.selectedGroupIds}}
        @labelProperty="name"
        @onChange={{action "setPermissionsGroups"}}
        @options={{hash
          filterPlaceholder="tagging.groups.select_groups_placeholder"
        }}
      />
    </div>
  </div>
  <div class="group-visibility-option">
    <RadioButton
      @name="tag-permissions-choice"
      @value="private"
      @id="private-permission"
      @selection={{this.buffered.permissionName}}
      class="tag-permissions-choice"
    />

    <label class="radio" for="private-permission">
      {{i18n "tagging.groups.visible_only_to_groups"}}
    </label>

    <div class="group-access-control">
      <GroupChooser
        @content={{this.allGroups}}
        @value={{this.selectedGroupIds}}
        @labelProperty="name"
        @onChange={{action "setPermissionsGroups"}}
        @options={{hash
          filterPlaceholder="tagging.groups.select_groups_placeholder"
        }}
      />
    </div>
  </div>
</section>

<div class="tag-group-controls">
  <DButton
    @action={{action "save"}}
    @disabled={{this.buffered.isSaving}}
    @label="tagging.groups.save"
    class="btn-primary"
  />

  <DButton
    @action={{this.destroyTagGroup}}
    @disabled={{this.buffered.isNew}}
    @icon="trash-can"
    @label="tagging.groups.delete"
    class="btn-danger"
  />
</div>