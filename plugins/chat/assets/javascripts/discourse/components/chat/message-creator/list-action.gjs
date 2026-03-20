import DButton from "discourse/ui-kit/d-button";

const ListAction = <template>
  <DButton
    class="btn btn-flat"
    @icon={{@item.icon}}
    @translatedLabel={{@item.label}}
  />
</template>;

export default ListAction;
