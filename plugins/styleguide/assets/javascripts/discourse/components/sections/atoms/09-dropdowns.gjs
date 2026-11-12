import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CategoriesAdminDropdownExample from "../../examples/atoms/dropdowns/categories-admin-dropdown.gjs";
import categoriesAdminDropdownSource from "../../examples/atoms/dropdowns/categories-admin-dropdown?source=file";
import CategoryChooserExample from "../../examples/atoms/dropdowns/category-chooser.gjs";
import categoryChooserSource from "../../examples/atoms/dropdowns/category-chooser?source=file";
import CategoryNotificationsTrackingExample from "../../examples/atoms/dropdowns/category-notifications-tracking.gjs";
import categoryNotificationsTrackingSource from "../../examples/atoms/dropdowns/category-notifications-tracking?source=file";
import ComboBoxExample from "../../examples/atoms/dropdowns/combo-box.gjs";
import comboBoxSource from "../../examples/atoms/dropdowns/combo-box?source=file";
import ComboBoxClearableExample from "../../examples/atoms/dropdowns/combo-box-clearable.gjs";
import comboBoxClearableSource from "../../examples/atoms/dropdowns/combo-box-clearable?source=file";
import ComboBoxFilterableExample from "../../examples/atoms/dropdowns/combo-box-filterable.gjs";
import comboBoxFilterableSource from "../../examples/atoms/dropdowns/combo-box-filterable?source=file";
import ComboBoxNoneExample from "../../examples/atoms/dropdowns/combo-box-none.gjs";
import comboBoxNoneSource from "../../examples/atoms/dropdowns/combo-box-none?source=file";
import DropdownSelectBoxExample from "../../examples/atoms/dropdowns/dropdown-select-box.gjs";
import dropdownSelectBoxSource from "../../examples/atoms/dropdowns/dropdown-select-box?source=file";
import FutureDateInputSelectorExample from "../../examples/atoms/dropdowns/future-date-input-selector.gjs";
import futureDateInputSelectorSource from "../../examples/atoms/dropdowns/future-date-input-selector?source=file";
import GroupChooserExample from "../../examples/atoms/dropdowns/group-chooser.gjs";
import groupChooserSource from "../../examples/atoms/dropdowns/group-chooser?source=file";
import IconGridPickerExample from "../../examples/atoms/dropdowns/icon-grid-picker.gjs";
import iconGridPickerSource from "../../examples/atoms/dropdowns/icon-grid-picker?source=file";
import ListSettingExample from "../../examples/atoms/dropdowns/list-setting.gjs";
import listSettingSource from "../../examples/atoms/dropdowns/list-setting?source=file";
import ListSettingNamePropertyExample from "../../examples/atoms/dropdowns/list-setting-name-property.gjs";
import listSettingNamePropertySource from "../../examples/atoms/dropdowns/list-setting-name-property?source=file";
import MiniTagChooserExample from "../../examples/atoms/dropdowns/mini-tag-chooser.gjs";
import miniTagChooserSource from "../../examples/atoms/dropdowns/mini-tag-chooser?source=file";
import MiniTagChooserHeaderFilterExample from "../../examples/atoms/dropdowns/mini-tag-chooser-header-filter.gjs";
import miniTagChooserHeaderFilterSource from "../../examples/atoms/dropdowns/mini-tag-chooser-header-filter?source=file";
import MultiSelectExample from "../../examples/atoms/dropdowns/multi-select.gjs";
import multiSelectSource from "../../examples/atoms/dropdowns/multi-select?source=file";
import PinnedButtonExample from "../../examples/atoms/dropdowns/pinned-button.gjs";
import pinnedButtonSource from "../../examples/atoms/dropdowns/pinned-button?source=file";
import PinnedOptionsExample from "../../examples/atoms/dropdowns/pinned-options.gjs";
import pinnedOptionsSource from "../../examples/atoms/dropdowns/pinned-options?source=file";
import TopicNotificationsTrackingExample from "../../examples/atoms/dropdowns/topic-notifications-tracking.gjs";
import topicNotificationsTrackingSource from "../../examples/atoms/dropdowns/topic-notifications-tracking?source=file";
import UserNotificationsDropdownExample from "../../examples/atoms/dropdowns/user-notifications-dropdown.gjs";
import userNotificationsDropdownSource from "../../examples/atoms/dropdowns/user-notifications-dropdown?source=file";

export default <template>
  <StyleguideExample @code={{comboBoxSource}} @title="<ComboBox>">
    <ComboBoxExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{comboBoxFilterableSource}}
    @title="filterable <ComboBox>"
  >
    <ComboBoxFilterableExample @categories={{@dummy.categories}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{comboBoxNoneSource}}
    @title="<ComboBox> with a default state"
  >
    <ComboBoxNoneExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{comboBoxClearableSource}}
    @title="<ComboBox> clearable"
  >
    <ComboBoxClearableExample />
  </StyleguideExample>

  <StyleguideExample
    @code={{topicNotificationsTrackingSource}}
    @title="<TopicNotificationsTracking>"
  >
    <TopicNotificationsTrackingExample />
  </StyleguideExample>

  <StyleguideExample @code={{categoryChooserSource}} @title="<CategoryChooser>">
    <CategoryChooserExample />
  </StyleguideExample>

  <StyleguideExample @code={{pinnedButtonSource}} @title="<PinnedButton>">
    <PinnedButtonExample @topic={{@dummy.pinnedTopic}} />
  </StyleguideExample>

  <StyleguideExample @code={{pinnedOptionsSource}} @title="<PinnedOptions>">
    <PinnedOptionsExample @topic={{@dummy.pinnedTopic}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{categoriesAdminDropdownSource}}
    @title="<CategoriesAdminDropdown>"
  >
    <CategoriesAdminDropdownExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{categoryNotificationsTrackingSource}}
    @title="<CategoryNotificationsTracking>"
  >
    <CategoryNotificationsTrackingExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{dropdownSelectBoxSource}}
    @title="<DropdownSelectBox>"
  >
    <DropdownSelectBoxExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{futureDateInputSelectorSource}}
    @title="<FutureDateInputSelector>"
  >
    <FutureDateInputSelectorExample />
  </StyleguideExample>

  <StyleguideExample @code={{multiSelectSource}} @title="<MultiSelect>">
    <MultiSelectExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample @code={{miniTagChooserSource}} @title="<MiniTagChooser>">
    <div class="inline-form">
      <MiniTagChooserExample />
    </div>
  </StyleguideExample>

  <StyleguideExample
    @code={{miniTagChooserHeaderFilterSource}}
    @title="<MiniTagChooser> with useHeaderFilter=true"
  >
    <div class="inline-form">
      <MiniTagChooserHeaderFilterExample />
    </div>
  </StyleguideExample>

  <StyleguideExample @code={{groupChooserSource}} @title="admin <GroupChooser>">
    <GroupChooserExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample @code={{listSettingSource}} @title="<ListSetting>">
    <ListSettingExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{listSettingNamePropertySource}}
    @title="<ListSetting> with a name property"
  >
    <ListSettingNamePropertyExample @onChange={{@dummyAction}} />
  </StyleguideExample>

  <StyleguideExample
    @code={{userNotificationsDropdownSource}}
    @title="<UserNotificationsDropdown>"
  >
    <UserNotificationsDropdownExample />
  </StyleguideExample>

  <StyleguideExample @code={{iconGridPickerSource}} @title="<DIconGridPicker>">
    <IconGridPickerExample />
  </StyleguideExample>
</template>
