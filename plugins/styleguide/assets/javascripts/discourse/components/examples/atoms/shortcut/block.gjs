import DButton from "discourse/ui-kit/d-button";
import DShortcut from "discourse/ui-kit/d-shortcut";

export default <template>
  <DShortcut @always={{true}} @keys="mod+b" as |shortcut|>
    <DButton
      class="btn-default"
      aria-keyshortcuts={{shortcut.aria}}
      @icon="bold"
      @translatedLabel="Bold"
    >
      <shortcut.Kbd />
    </DButton>
  </DShortcut>
</template>
