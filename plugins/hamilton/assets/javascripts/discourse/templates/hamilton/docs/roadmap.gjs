import { trustHTML } from "@ember/template";

export default <template>
  <article class="hamilton__docs cooked">{{trustHTML @model.html}}</article>
</template>
