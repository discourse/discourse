import Component from "@glimmer/component";
import { formatShortcut } from "discourse/lib/shortcut-format";
import DShortcut from "discourse/ui-kit/d-shortcut";

const SPELLINGS = [
  "mod+k",
  "meta+shift+d",
  "ctrl+m",
  "cmd+alt+1",
  "shift+up",
  "&darr;",
  "mod+.",
  "mod+plus",
  "g+h",
];

export default class SpellingsExample extends Component {
  get rows() {
    return SPELLINGS.map((spelling) => ({
      spelling,
      announced: formatShortcut(spelling).aria,
    }));
  }

  <template>
    <table class="styleguide-shortcut-spellings">
      <thead>
        <tr>
          <th>Spelling</th>
          <th>Drawn</th>
          <th>Announced</th>
        </tr>
      </thead>
      <tbody>
        {{#each this.rows key="spelling" as |row|}}
          <tr>
            <td><code>{{row.spelling}}</code></td>
            <td><DShortcut @always={{true}} @keys={{row.spelling}} /></td>
            <td><code>{{row.announced}}</code></td>
          </tr>
        {{/each}}
      </tbody>
    </table>
  </template>
}
