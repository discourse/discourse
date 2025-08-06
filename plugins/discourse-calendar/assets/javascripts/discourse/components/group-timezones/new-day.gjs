import icon from "discourse/helpers/d-icon";

const NewDay = <template>
  <div class="group-timezone-new-day">
    <span class="before">
      {{icon "chevron-left"}}
      {{@beforeDate}}
    </span>
    <span class="after">
      {{@afterDate}}
      {{icon "chevron-right"}}
    </span>
  </div>
</template>;

export default NewDay;
