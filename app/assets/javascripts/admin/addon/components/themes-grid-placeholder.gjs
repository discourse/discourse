import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";

export default class ThemesGridPlaceholder extends Component {
  get themeColors() {
    if (this.args.theme.color_scheme) {
      return {
        primary: `#${this.args.theme.color_scheme.colors[0].hex}`,
        secondary: `#${this.args.theme.color_scheme.colors[1].hex}`,
        tertiary: `#${this.args.theme.color_scheme.colors[2].hex}`,
        quaternary: `#${this.args.theme.color_scheme.colors[3].hex}`,
        highlight: `#${this.args.theme.color_scheme.colors[6].hex}`,
        danger: `#${this.args.theme.color_scheme.colors[7].hex}`,
        success: `#${this.args.theme.color_scheme.colors[8].hex}`,
        love: `#${this.args.theme.color_scheme.colors[9].hex}`,
      };
    } else {
      return {
        primary: "var(--primary)",
        secondary: "var(--secondary)",
        tertiary: "var(--tertiary)",
        quaternary: "var(--quaternary)",
        highlight: "var(--highlight)",
        danger: "var(--danger)",
        success: "var(--success)",
        love: "var(--love)",
      };
    }
  }

  <template>
    <svg viewBox="0 0 636 347" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect
        width="635.115"
        height="347"
        fill={{htmlSafe this.themeColors.secondary}}
      />
      <path
        d="M54.9766 79.1039C55.9198 76.0065 59.8623 75.0916 62.0732 77.4571L121.448 140.986C123.659 143.351 122.48 147.223 119.326 147.955L34.621 167.611C31.467 168.343 28.7034 165.386 29.6466 162.288L54.9766 79.1039Z"
        fill={{htmlSafe this.themeColors.primary}}
      />
      <path
        d="M398.487 211.02C400.651 208.611 404.611 209.448 405.615 212.527L432.579 295.196C433.584 298.274 430.879 301.285 427.711 300.615L342.635 282.633C339.467 281.963 338.212 278.115 340.376 275.707L398.487 211.02Z"
        fill={{htmlSafe this.themeColors.tertiary}}
      />
      <circle cx="109.357" cy="262.879" r="44.1636" fill="#D1F0FF" />
      <circle cx="365.927" cy="103.048" r="44.1636" fill="#E45735" />
      <rect
        x="166.139"
        y="68.751"
        width="81.9226"
        height="81.9226"
        rx="4.20606"
        transform="rotate(-15.9297 166.139 68.751)"
        fill={{htmlSafe this.themeColors.danger}}
      />
      <rect
        x="500.521"
        y="100.296"
        width="81.9226"
        height="81.9226"
        rx="4.20606"
        transform="rotate(-15.9297 500.521 100.296)"
        fill={{htmlSafe this.themeColors.success}}
      />
      <rect
        x="481.857"
        y="222.921"
        width="121.976"
        height="54.6788"
        rx="4.20606"
        transform="rotate(9.12857 481.857 222.921)"
        fill={{htmlSafe this.themeColors.love}}
      />
      <rect
        x="176.654"
        y="240.608"
        width="121.976"
        height="54.6788"
        rx="4.20606"
        transform="rotate(-22.7296 176.654 240.608)"
        fill={{htmlSafe this.themeColors.primary}}
      />
    </svg>
  </template>
}
