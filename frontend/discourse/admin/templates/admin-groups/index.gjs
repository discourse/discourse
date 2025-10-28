import GroupList from "discourse/components/group-list";

export default <template>
  <GroupList
    @groups={{@model.groups}}
    @type={{@controller.type}}
    @filter={{@controller.filter}}
    @onTypeChanged={{@controller.onTypeChanged}}
    @onFilterChanged={{@controller.onFilterChanged}}
  />
</template>
