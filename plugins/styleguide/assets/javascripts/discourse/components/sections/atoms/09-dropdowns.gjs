import Component from "@glimmer/component";
import { fn, get, hash } from "@ember/helper";
import CategoryNotificationsTracking from "discourse/components/category-notifications-tracking";
import PinnedButton from "discourse/components/pinned-button";
import PinnedOptions from "discourse/components/pinned-options";
import TopicNotificationsTracking from "discourse/components/topic-notifications-tracking";
import CategoriesAdminDropdown from "discourse/select-kit/components/categories-admin-dropdown";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import ComboBox from "discourse/select-kit/components/combo-box";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";
import FutureDateInputSelector from "discourse/select-kit/components/future-date-input-selector";
import GroupChooser from "discourse/select-kit/components/group-chooser";
import IconPicker from "discourse/select-kit/components/icon-picker";
import ListSetting from "discourse/select-kit/components/list-setting";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import MultiSelect from "discourse/select-kit/components/multi-select";
import UserNotificationsDropdown from "discourse/select-kit/components/user-notifications-dropdown";
import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";

export default class Dropdowns extends Component {
  get comboBoxCode() {
    return `
import { fn } from "@ember/helper";
import { mut } from "discourse/helpers/mut";
import ComboBox from "discourse/select-kit/components/combo-box";

<template>
  <ComboBox
    @content={{@dummy.options}}
    @value={{value}}
    @onChange={{fn (mut value)}}
  />
</template>
    `;
  }

  get comboBoxFilterableCode() {
    return `
import { fn, hash } from "@ember/helper";
import { mut } from "discourse/helpers/mut";
import ComboBox from "discourse/select-kit/components/combo-box";

<template>
  <ComboBox
    @content={{@dummy.categories}}
    @value={{value}}
    @options={{hash filterable=true}}
    @onChange={{fn (mut value)}}
  />
</template>
    `;
  }

  get comboBoxDefaultStateCode() {
    return `
import { fn, hash } from "@ember/helper";
import { mut } from "discourse/helpers/mut";
import ComboBox from "discourse/select-kit/components/combo-box";

<template>
  <ComboBox
    @content={{@dummy.options}}
    @value={{value}}
    @options={{hash none="category.none"}}
    @onChange={{fn (mut value)}}
  />
</template>
    `;
  }

  get comboBoxClearableCode() {
    return `
import { fn, hash } from "@ember/helper";
import { mut } from "discourse/helpers/mut";
import ComboBox from "discourse/select-kit/components/combo-box";

<template>
  <ComboBox
    @content={{@dummy.options}}
    @clearable={{true}}
    @value={{value}}
    @options={{hash none="category.none"}}
    @onChange={{fn (mut value)}}
  />
</template>
    `;
  }

  get topicNotificationsTrackingCode() {
    return `
import { fn } from "@ember/helper";
import { mut } from "discourse/helpers/mut";
import TopicNotificationsTracking from "discourse/components/topic-notifications-tracking";

<template>
  <TopicNotificationsTracking
    @levelId={{value}}
    @onChange={{fn (mut value)}}
  />
</template>
    `;
  }

  get categoryChooserCode() {
    return `
import { fn } from "@ember/helper";
import { mut } from "discourse/helpers/mut";
import CategoryChooser from "discourse/select-kit/components/category-chooser";

<template>
  <CategoryChooser @value={{value}} @onChange={{fn (mut value)}} />
</template>
    `;
  }

  get pinnedButtonCode() {
    return `
import PinnedButton from "discourse/components/pinned-button";

<template>
  <PinnedButton @topic={{@dummy.pinnedTopic}} @pinned={{true}} />
</template>
    `;
  }

  get pinnedOptionsCode() {
    return `
import PinnedOptions from "discourse/components/pinned-options";

<template>
  <PinnedOptions @topic={{@dummy.pinnedTopic}} />
</template>
    `;
  }

  get categoriesAdminDropdownCode() {
    return `
import CategoriesAdminDropdown from "discourse/select-kit/components/categories-admin-dropdown";

<template>
  <CategoriesAdminDropdown @onChange={{@dummyAction}} />
</template>
    `;
  }

  get categoryNotificationsTrackingCode() {
    return `
import CategoryNotificationsTracking from "discourse/components/category-notifications-tracking";

<template>
  <CategoryNotificationsTracking @levelId={{1}} @onChange={{@dummyAction}} />
</template>
    `;
  }

  get dropdownSelectBoxCode() {
    return `
import { hash } from "@ember/helper";
import DropdownSelectBox from "discourse/select-kit/components/dropdown-select-box";

<template>
  <DropdownSelectBox
    @content={{@dummy.options}}
    @onChange={{@dummyAction}}
    @options={{hash translatedNone="Something"}}
  />
</template>
    `;
  }

  get futureDateInputSelectorCode() {
    return `
import { hash } from "@ember/helper";
import FutureDateInputSelector from "discourse/select-kit/components/future-date-input-selector";

<template>
  <FutureDateInputSelector
    @input={{@dummy.topicTimerUpdateDate}}
    @includeWeekend={{true}}
    @includeForever={{true}}
    @options={{hash none="time_shortcut.select_timeframe"}}
  />
</template>
    `;
  }

  get multiSelectCode() {
    return `
import MultiSelect from "discourse/select-kit/components/multi-select";

<template>
  <MultiSelect @content={{@dummy.options}} @onChange={{@dummyAction}} />
</template>
    `;
  }

  get miniTagChooserCode() {
    return `
import { hash } from "@ember/helper";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";

<template>
  <MiniTagChooser
    @value={{@dummy.selectedTags}}
    @options={{hash filterable=true}}
  />
</template>
    `;
  }

  get miniTagChooserHeaderFilterCode() {
    return `
import { hash } from "@ember/helper";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";

<template>
  <MiniTagChooser
    @value={{@dummy.selectedTags}}
    @options={{hash
      filterable=true
      filterPlaceholder="tagging.choose_for_topic"
      useHeaderFilter=true
    }}
  />
</template>
    `;
  }

  get groupChooserCode() {
    return `
import GroupChooser from "discourse/select-kit/components/group-chooser";

<template>
  <GroupChooser
    @selected={{@dummy.selectedGroups}}
    @content={{@dummy.groups}}
    @onChange={{@dummyAction}}
  />
</template>
    `;
  }

  get listSettingCode() {
    return `
import ListSetting from "discourse/select-kit/components/list-setting";

<template>
  <ListSetting @settingValue={{@dummy.settings}} @onChange={{@dummyAction}} />
</template>
    `;
  }

  get listSettingNamePropertyCode() {
    return `
import ListSetting from "discourse/select-kit/components/list-setting";

<template>
  <ListSetting
    @settingValue={{@dummy.colors}}
    @nameProperty="color"
    @onChange={{@dummyAction}}
  />
</template>
    `;
  }

  get userNotificationsDropdownCode() {
    return `
import UserNotificationsDropdown from "discourse/select-kit/components/user-notifications-dropdown";

<template>
  <UserNotificationsDropdown @user={{@currentUser}} @value="changeToNormal" />
</template>
    `;
  }

  get iconPickerCode() {
    return `
import IconPicker from "discourse/select-kit/components/icon-picker";

<template>
  <IconPicker @name="icon" />
</template>
    `;
  }

  <template>
    <StyleguideExample
      @title="<ComboBox>"
      @code={{this.comboBoxCode}}
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
      @code={{this.comboBoxFilterableCode}}
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
      @code={{this.comboBoxDefaultStateCode}}
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
      @code={{this.comboBoxClearableCode}}
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
      @code={{this.topicNotificationsTrackingCode}}
      @initialValue={{1}}
      as |value|
    >
      <TopicNotificationsTracking
        @levelId={{value}}
        @onChange={{fn (mut value)}}
      />
    </StyleguideExample>

    <StyleguideExample
      @title="<CategoryChooser>"
      @code={{this.categoryChooserCode}}
      @initialValue={{get @categories "0" "name"}}
      as |value|
    >
      <CategoryChooser @value={{value}} @onChange={{fn (mut value)}} />
    </StyleguideExample>

    <StyleguideExample @title="<PinnedButton>" @code={{this.pinnedButtonCode}}>
      <PinnedButton @topic={{@dummy.pinnedTopic}} @pinned={{true}} />
    </StyleguideExample>

    <StyleguideExample
      @title="<PinnedOptions>"
      @code={{this.pinnedOptionsCode}}
    >
      <PinnedOptions @topic={{@dummy.pinnedTopic}} />
    </StyleguideExample>

    <StyleguideExample
      @title="<CategoriesAdminDropdown>"
      @code={{this.categoriesAdminDropdownCode}}
    >
      <CategoriesAdminDropdown @onChange={{@dummyAction}} />
    </StyleguideExample>

    <StyleguideExample
      @title="<CategoryNotificationsTracking>"
      @code={{this.categoryNotificationsTrackingCode}}
    >
      <CategoryNotificationsTracking
        @levelId={{1}}
        @onChange={{@dummyAction}}
      />
    </StyleguideExample>

    <StyleguideExample
      @title="<DropdownSelectBox>"
      @code={{this.dropdownSelectBoxCode}}
    >
      <DropdownSelectBox
        @content={{@dummy.options}}
        @onChange={{@dummyAction}}
        @options={{hash translatedNone="Something"}}
      />
    </StyleguideExample>

    <StyleguideExample
      @title="<FutureDateInputSelector>"
      @code={{this.futureDateInputSelectorCode}}
    >
      <FutureDateInputSelector
        @input={{@dummy.topicTimerUpdateDate}}
        @includeWeekend={{true}}
        @includeForever={{true}}
        @options={{hash none="time_shortcut.select_timeframe"}}
      />
    </StyleguideExample>

    <StyleguideExample @title="<MultiSelect>" @code={{this.multiSelectCode}}>
      <MultiSelect @content={{@dummy.options}} @onChange={{@dummyAction}} />
    </StyleguideExample>

    <StyleguideExample
      @title="<MiniTagChooser>"
      @code={{this.miniTagChooserCode}}
    >
      <div class="inline-form">
        <MiniTagChooser
          @value={{@dummy.selectedTags}}
          @options={{hash filterable=true}}
        />
      </div>
    </StyleguideExample>

    <StyleguideExample
      @title="<MiniTagChooser> with useHeaderFilter=true"
      @code={{this.miniTagChooserHeaderFilterCode}}
    >
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

    <StyleguideExample
      @title="admin <GroupChooser>"
      @code={{this.groupChooserCode}}
    >
      <GroupChooser
        @selected={{@dummy.selectedGroups}}
        @content={{@dummy.groups}}
        @onChange={{@dummyAction}}
      />
    </StyleguideExample>

    <StyleguideExample @title="<ListSetting>" @code={{this.listSettingCode}}>
      <ListSetting
        @settingValue={{@dummy.settings}}
        @onChange={{@dummyAction}}
      />
    </StyleguideExample>

    <StyleguideExample
      @title="<ListSetting>"
      @code={{this.listSettingNamePropertyCode}}
    >
      <ListSetting
        @settingValue={{@dummy.colors}}
        @nameProperty="color"
        @onChange={{@dummyAction}}
      />
    </StyleguideExample>

    <StyleguideExample
      @title="<UserNotificationsDropdown>"
      @code={{this.userNotificationsDropdownCode}}
    >
      <UserNotificationsDropdown
        @user={{@currentUser}}
        @value="changeToNormal"
      />
    </StyleguideExample>

    <StyleguideExample @title="<IconPicker>" @code={{this.iconPickerCode}}>
      <IconPicker @name="icon" />
    </StyleguideExample>
  </template>
}
