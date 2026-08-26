import DShortcut from "discourse/ui-kit/d-shortcut";

export default <template>
  <p><DShortcut @keys="mod+enter" /></p>
  <p><DShortcut @keys="ctrl+alt+f" /></p>
  <p><DShortcut @keys="shift+up" /></p>
  <p><DShortcut @keys="g+h" /></p>
</template>
