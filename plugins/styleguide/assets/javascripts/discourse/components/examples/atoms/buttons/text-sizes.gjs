import DButton from "discourse/ui-kit/d-button";

export default <template>
  <DButton class="btn-default btn-large" @translatedLabel="large" />
  <DButton class="btn-default" @translatedLabel="default" />
  <DButton class="btn-default btn-small" @translatedLabel="small" />
</template>
