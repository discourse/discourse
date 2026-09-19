import ListSetting from "discourse/select-kit/components/list-setting";

export default <template>
  <ListSetting
    @onChange={{@onChange}}
    @settingValue="bold|italic|strike|underline"
  />
</template>
