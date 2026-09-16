import StyleguideExample from "discourse/plugins/styleguide/discourse/components/styleguide-example";
import CategoriesAdminDropdownExample from "../../examples/atoms/dropdowns/categories-admin-dropdown";
import categoriesAdminDropdownSource from "../../examples/atoms/dropdowns/categories-admin-dropdown?source=file";
import CategoryChooserExample from "../../examples/atoms/dropdowns/category-chooser";
import categoryChooserSource from "../../examples/atoms/dropdowns/category-chooser?source=file";
import CategoryNotificationsTrackingExample from "../../examples/atoms/dropdowns/category-notifications-tracking";
import categoryNotificationsTrackingSource from "../../examples/atoms/dropdowns/category-notifications-tracking?source=file";
import ComboBoxExample from "../../examples/atoms/dropdowns/combo-box";
import comboBoxSource from "../../examples/atoms/dropdowns/combo-box?source=file";
import ComboBoxClearableExample from "../../examples/atoms/dropdowns/combo-box-clearable";
import comboBoxClearableSource from "../../examples/atoms/dropdowns/combo-box-clearable?source=file";
import ComboBoxFilterableExample from "../../examples/atoms/dropdowns/combo-box-filterable";
import comboBoxFilterableSource from "../../examples/atoms/dropdowns/combo-box-filterable?source=file";
import ComboBoxNoneExample from "../../examples/atoms/dropdowns/combo-box-none";
import comboBoxNoneSource from "../../examples/atoms/dropdowns/combo-box-none?source=file";
import DropdownSelectBoxExample from "../../examples/atoms/dropdowns/dropdown-select-box";
import dropdownSelectBoxSource from "../../examples/atoms/dropdowns/dropdown-select-box?source=file";
import FutureDateInputSelectorExample from "../../examples/atoms/dropdowns/future-date-input-selector";
import futureDateInputSelectorSource from "../../examples/atoms/dropdowns/future-date-input-selector?source=file";
import GroupChooserExample from "../../examples/atoms/dropdowns/group-chooser";
import groupChooserSource from "../../examples/atoms/dropdowns/group-chooser?source=file";
import IconGridPickerExample from "../../examples/atoms/dropdowns/icon-grid-picker";
import iconGridPickerSource from "../../examples/atoms/dropdowns/icon-grid-picker?source=file";
import ListSettingExample from "../../examples/atoms/dropdowns/list-setting";
import listSettingSource from "../../examples/atoms/dropdowns/list-setting?source=file";
import ListSettingNamePropertyExample from "../../examples/atoms/dropdowns/list-setting-name-property";
import listSettingNamePropertySource from "../../examples/atoms/dropdowns/list-setting-name-property?source=file";
import MiniTagChooserExample from "../../examples/atoms/dropdowns/mini-tag-chooser";
import miniTagChooserSource from "../../examples/atoms/dropdowns/mini-tag-chooser?source=file";
import MiniTagChooserHeaderFilterExample from "../../examples/atoms/dropdowns/mini-tag-chooser-header-filter";
import miniTagChooserHeaderFilterSource from "../../examples/atoms/dropdowns/mini-tag-chooser-header-filter?source=file";
import MultiSelectExample from "../../examples/atoms/dropdowns/multi-select";
import multiSelectSource from "../../examples/atoms/dropdowns/multi-select?source=file";
import PinnedButtonExample from "../../examples/atoms/dropdowns/pinned-button";
import pinnedButtonSource from "../../examples/atoms/dropdowns/pinned-button?source=file";
import PinnedOptionsExample from "../../examples/atoms/dropdowns/pinned-options";
import pinnedOptionsSource from "../../examples/atoms/dropdowns/pinned-options?source=file";
import TopicNotificationsTrackingExample from "../../examples/atoms/dropdowns/topic-notifications-tracking";
import topicNotificationsTrackingSource from "../../examples/atoms/dropdowns/topic-notifications-tracking?source=file";
import UserNotificationsDropdownExample from "../../examples/atoms/dropdowns/user-notifications-dropdown";
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
