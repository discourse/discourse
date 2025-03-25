<ListSetting
  @value={{this.settingValue}}
  @settingName={{this.setting.setting}}
  @choices={{this.settingChoices}}
  @nameProperty="name"
  @valueProperty="value"
  @onChange={{this.onChangeListSetting}}
  @options={{hash allowAny=this.allowAny}}
/>