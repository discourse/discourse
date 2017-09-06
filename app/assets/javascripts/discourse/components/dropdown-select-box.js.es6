import SelectBoxComponent from "discourse/components/select-box";

export default SelectBoxComponent.extend({
  classNames: ["dropdown-select-box"],
  wrapper: false,
  verticalOffset: 3,
  collectionHeight: "auto",

  selectBoxHeaderComponent: "dropdown-select-box/dropdown-header"
});
