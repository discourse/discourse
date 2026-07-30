import GroupChooser from "discourse/select-kit/components/group-chooser";

const GROUPS = [
  { name: "staff", id: 1, automatic: false },
  { name: "lounge", id: 2, automatic: true },
  { name: "admin", id: 3, automatic: false },
];

const SELECTED = [1, 2];

export default <template>
  <GroupChooser
    @selected={{SELECTED}}
    @content={{GROUPS}}
    @onChange={{@onChange}}
  />
</template>
