import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton class="btn-default" @translatedLabel="normal" />
  <DButton class="btn-default btn-hover" @translatedLabel="hover" />
  <DButton class="btn-default" @disabled={{true}} @translatedLabel="disabled" />
</template>
