import DShortcut from "discourse/ui-kit/d-shortcut";

export default <template>
  <p><DShortcut @always={{true}} @keys="mod+enter" /></p>
  <p><DShortcut @always={{true}} @keys="ctrl+alt+f" /></p>
  <p><DShortcut @always={{true}} @keys="shift+up" /></p>
  <p><DShortcut @always={{true}} @keys="g+h" /></p>
</template>
