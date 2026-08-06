import ListSetting from "discourse/select-kit/components/list-setting";

export default <template>
  <ListSetting
    @settingValue="bold|italic|strike|underline"
    @onChange={{@onChange}}
  />
</template>
