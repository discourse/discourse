import Component from "@glimmer/component";

export default class LazyVideo extends Component {
  get iframeSrc() {
    switch (this.args.providerName) {
      case "youtube":
        return `https://www.youtube.com/embed/${this.args.videoId}?autoplay=1`;
      case "vimeo":
        return `https://player.vimeo.com/video/${this.args.videoId}${
          this.args.videoId.includes("?") ? "&" : "?"
        }autoplay=1`;
      case "tiktok":
        return `https://www.tiktok.com/embed/v2/${this.args.videoId}`;
    }
  }
}
