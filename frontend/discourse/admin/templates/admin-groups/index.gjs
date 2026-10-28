import GroupList from "discourse/components/group-list";

export default <template>
  <GroupList
    @filter={{@controller.filter}}
    @groups={{@model.groups}}
    @onFilterChanged={{@controller.onFilterChanged}}
    @onTypeChanged={{@controller.onTypeChanged}}
    @type={{@controller.type}}
  />
</template>
