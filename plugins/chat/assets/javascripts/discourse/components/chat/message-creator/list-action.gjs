import dIcon from "discourse/ui-kit/helpers/d-icon";

const ListAction = <template>
  <div class="chat-message-creator__chatable -group">
    <div class="chat-message-creator__group-icon">
      {{dIcon @item.icon}}
    </div>
    <div class="chat-message-creator__group-name">
      {{@item.label}}
    </div>
  </div>
</template>;

export default ListAction;
