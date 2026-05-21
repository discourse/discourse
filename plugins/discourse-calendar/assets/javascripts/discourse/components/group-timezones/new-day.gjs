import dIcon from "discourse/ui-kit/helpers/d-icon";

const NewDay = <template>
  <div class="group-timezone-new-day">
    <span class="before">
      {{dIcon "chevron-left"}}
      {{@beforeDate}}
    </span>
    <span class="after">
      {{@afterDate}}
      {{dIcon "chevron-right"}}
    </span>
  </div>
</template>;

export default NewDay;
