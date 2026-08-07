import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton @translatedLabel="normal" class="btn-default" />
  <DButton @translatedLabel="hover" class="btn-default btn-hover" />
  <DButton @translatedLabel="disabled" @disabled={{true}} class="btn-default" />
</template>
