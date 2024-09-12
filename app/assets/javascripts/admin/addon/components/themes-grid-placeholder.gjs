import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";

// eslint-disable-next-line ember/no-empty-glimmer-component-classes
export default class ThemesGridPlaceholder extends Component {

  get themeColors() {
    if (this.args.theme.color_scheme) {
      return {
        "primary": "#" + this.args.theme.color_scheme.colors[0].hex,
        "secondary": "#" + this.args.theme.color_scheme.colors[1].hex,
        "tertiary": "#" + this.args.theme.color_scheme.colors[2].hex,
        "quaternary": "#" + this.args.theme.color_scheme.colors[3].hex,
        "highlight": "#" + this.args.theme.color_scheme.colors[6].hex,
        "danger": "#" + this.args.theme.color_scheme.colors[7].hex,
        "success": "#" + this.args.theme.color_scheme.colors[8].hex,
        "love": "#" + this.args.theme.color_scheme.colors[9].hex,
      } 
      } else {
      return {
        "primary": "var(--primary)",
        "secondary": "var(--secondary)",
        "tertiary": "var(--tertiary)",
        "quaternary": "var(--quaternary)",
        "highlight": "var(--highlight)",
        "danger": "var(--danger)",
        "success": "var(--success)",
        "love": "var(--love)",
      }
    }
  }
  <template>
    <svg viewBox="0 0 636 347" fill="none" xmlns="http://www.w3.org/2000/svg">
    <rect width="635.115" height="347" fill="{{htmlSafe this.themeColors.secondary}}"/>
    <path d="M54.9766 79.1039C55.9198 76.0065 59.8623 75.0916 62.0732 77.4571L121.448 140.986C123.659 143.351 122.48 147.223 119.326 147.955L34.621 167.611C31.467 168.343 28.7034 165.386 29.6466 162.288L54.9766 79.1039Z" fill="{{htmlSafe this.themeColors.primary}}"/>
    <path d="M398.487 211.02C400.651 208.611 404.611 209.448 405.615 212.527L432.579 295.196C433.584 298.274 430.879 301.285 427.711 300.615L342.635 282.633C339.467 281.963 338.212 278.115 340.376 275.707L398.487 211.02Z" fill="{{htmlSafe this.themeColors.tertiary}}"/>
    <circle cx="109.357" cy="262.879" r="44.1636" fill="#D1F0FF"/>
    <circle cx="365.927" cy="103.048" r="44.1636" fill="#E45735"/>
    <rect x="166.139" y="68.751" width="81.9226" height="81.9226" rx="4.20606" transform="rotate(-15.9297 166.139 68.751)" fill="{{htmlSafe this.themeColors.danger}}"/>
    <rect x="500.521" y="100.296" width="81.9226" height="81.9226" rx="4.20606" transform="rotate(-15.9297 500.521 100.296)" fill="{{htmlSafe this.themeColors.success}}"/>
    <rect x="481.857" y="222.921" width="121.976" height="54.6788" rx="4.20606" transform="rotate(9.12857 481.857 222.921)" fill="{{htmlSafe this.themeColors.love}}"/>
    <rect x="176.654" y="240.608" width="121.976" height="54.6788" rx="4.20606" transform="rotate(-22.7296 176.654 240.608)" fill="{{htmlSafe this.themeColors.primary}}"/>
    </svg>

    {{!-- <svg width="302" height="165" viewBox="0 0 302 165" fill="none" xmlns="http://www.w3.org/2000/svg">
    <rect width="302" height="165" fill="{{htmlSafe this.themeColors.secondary}}"/>
    <path d="M26.1416 37.6142C26.5901 36.1414 28.4648 35.7064 29.5161 36.8312L57.7491 67.0394C58.8003 68.1642 58.2397 70.0052 56.74 70.3532L16.4624 79.6997C14.9627 80.0477 13.6486 78.6417 14.0971 77.1688L26.1416 37.6142Z" fill="{{htmlSafe this.themeColors.primary}}"/>
    <path d="M189.482 100.341C190.511 99.1956 192.394 99.5936 192.872 101.057L205.694 140.367C206.171 141.83 204.885 143.262 203.378 142.944L162.925 134.393C161.418 134.075 160.821 132.245 161.85 131.1L189.482 100.341Z" fill="{{htmlSafe this.themeColors.tertiary}}"/>
    <circle cx="52" cy="125" r="21" fill="{{htmlSafe this.themeColors.quaternary}}"/>
    <circle cx="174" cy="49" r="21" fill="{{htmlSafe this.themeColors.highlight}}"/>
    <rect x="79" y="32.6914" width="38.9545" height="38.9545" rx="2" transform="rotate(-15.9297 79 32.6914)" fill="{{htmlSafe this.themeColors.danger}}"/>
    <rect x="238" y="47.6914" width="38.9545" height="38.9545" rx="2" transform="rotate(-15.9297 238 47.6914)" fill="{{htmlSafe this.themeColors.success}}"/>
    <rect x="229.125" y="106" width="58" height="26" rx="2" transform="rotate(9.12857 229.125 106)" fill="{{htmlSafe this.themeColors.love}}"/>
    <rect x="84" y="114.41" width="58" height="26" rx="2" transform="rotate(-22.7296 84 114.41)" fill="{{htmlSafe this.themeColors.primary}}"/>
    </svg> --}}
  </template>
}
