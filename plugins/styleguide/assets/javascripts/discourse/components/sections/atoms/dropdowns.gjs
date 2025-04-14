<StyleguideExample
  @title="<ComboBox>"
  @initialValue={{get @dummy "options.0.name"}}
  as |value|
>
  <ComboBox
    @content={{@dummy.options}}
    @value={{value}}
    @onChange={{fn (mut value)}}
  />
</StyleguideExample>

<StyleguideExample
  @title="filterable <ComboBox>"
  @initialValue={{get @dummy "categories.0.name"}}
  as |value|
>
  <ComboBox
    @content={{@dummy.categories}}
    @value={{value}}
    @options={{hash filterable=true}}
    @onChange={{fn (mut value)}}
  />
</StyleguideExample>

<StyleguideExample
  @title="<ComboBox> with a default state"
  @initialValue={{get @dummy "options.0.name"}}
  as |value|
>
  <ComboBox
    @content={{@dummy.options}}
    @value={{value}}
    @options={{hash none="category.none"}}
    @onChange={{fn (mut value)}}
  />
</StyleguideExample>

<StyleguideExample
  @title="<ComboBox> clearable"
  @initialValue={{get @dummy "options.0.name"}}
  as |value|
>
  <ComboBox
    @content={{@dummy.options}}
    @clearable={{true}}
    @value={{value}}
    @options={{hash none="category.none"}}
    @onChange={{fn (mut value)}}
  />
</StyleguideExample>

<StyleguideExample
  @title="<TopicNotificationsTracking>"
  @initialValue={{1}}
  as |value|
>
  <TopicNotificationsTracking @levelId={{value}} @onChange={{fn (mut value)}} />
</StyleguideExample>

<StyleguideExample
  @title="<CategoryChooser>"
  @initialValue={{get @categories "0" "name"}}
  as |value|
>
  <CategoryChooser @value={{value}} @onChange={{fn (mut value)}} />
</StyleguideExample>

<StyleguideExample @title="<PinnedButton>">
  <PinnedButton @topic={{@dummy.pinnedTopic}} />
</StyleguideExample>

<StyleguideExample @title="<PinnedOptions>">
  <PinnedOptions @topic={{@dummy.pinnedTopic}} />
</StyleguideExample>

<StyleguideExample @title="<CategoriesAdminDropdown>">
  <CategoriesAdminDropdown @onChange={{@dummyAction}} />
</StyleguideExample>

<StyleguideExample @title="<CategoryNotificationsTracking>">
  <CategoryNotificationsTracking @levelId={{1}} @onChange={{@dummyAction}} />
</StyleguideExample>

<StyleguideExample @title="<DropdownSelectBox>">
  <DropdownSelectBox
    @content={{@dummy.options}}
    @onChange={{@dummyAction}}
    @options={{hash translatedNone="Something"}}
  />
</StyleguideExample>

<StyleguideExample @title="<FutureDateInputSelector>">
  <FutureDateInputSelector
    @input={{@dummy.topicTimerUpdateDate}}
    @includeWeekend={{true}}
    @includeForever={{true}}
    @options={{hash none="time_shortcut.select_timeframe"}}
  />
</StyleguideExample>

<StyleguideExample @title="<MultiSelect>">
  <MultiSelect @content={{@dummy.options}} @onChange={{@dummyAction}} />
</StyleguideExample>

<StyleguideExample @title="<MiniTagChooser>">
  <div class="inline-form">
    <MiniTagChooser
      @value={{@dummy.selectedTags}}
      @options={{hash filterable=true}}
    />
  </div>
</StyleguideExample>

<StyleguideExample @title="<MiniTagChooser> with useHeaderFilter=true">
  <div class="inline-form">
    <MiniTagChooser
      @value={{@dummy.selectedTags}}
      @options={{hash
        filterable=true
        filterPlaceholder="tagging.choose_for_topic"
        useHeaderFilter=true
      }}
    />
  </div>
</StyleguideExample>

<StyleguideExample @title="admin <GroupChooser>">
  <GroupChooser
    @selected={{@dummy.selectedGroups}}
    @content={{@dummy.groups}}
    @onChange={{@dummyAction}}
  />
</StyleguideExample>

<StyleguideExample @title="<ListSetting>">
  <ListSetting @settingValue={{@dummy.settings}} @onChange={{@dummyAction}} />
</StyleguideExample>

<StyleguideExample @title="<ListSetting>">
  <ListSetting
    @settingValue={{@dummy.colors}}
    @nameProperty="color"
    @onChange={{@dummyAction}}
  />
</StyleguideExample>

<StyleguideExample @title="<UserNotificationsDropdown>">
  <UserNotificationsDropdown @user={{@currentUser}} @value="changeToNormal" />
</StyleguideExample>

<StyleguideExample @title="<IconPicker>">
  <IconPicker @name="icon" />
</StyleguideExample>