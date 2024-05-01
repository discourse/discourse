import Component from "@glimmer/component";

function convertToSeconds(time) {
  const match = time.toString().match(/(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?/);
  const [hours, minutes, seconds] = match.slice(1);

  if (hours || minutes || seconds) {
    const h = parseInt(hours, 10) || 0;
    const m = parseInt(minutes, 10) || 0;
    const s = parseInt(seconds, 10) || 0;

    return h * 3600 + m * 60 + s;
  }
  return time;
}

export default class LazyIframe extends Component {
  get iframeSrc() {
    switch (this.args.providerName) {
      case "youtube":
        let url = `https://www.youtube.com/embed/${this.args.videoId}?autoplay=1&rel=0`;
        if (this.args.startTime) {
          url += `&start=${convertToSeconds(this.args.startTime)}`;
        }
        return url;
      case "vimeo":
        return `https://player.vimeo.com/video/${this.args.videoId}${
          this.args.videoId.includes("?") ? "&" : "?"
        }autoplay=1`;
      case "tiktok":
        return `https://www.tiktok.com/embed/v2/${this.args.videoId}`;
    }
  }

  <template>
    {{#if @providerName}}
      <iframe
        src={{this.iframeSrc}}
        title={{@title}}
        allowFullScreen
        scrolling="no"
        frameborder="0"
        seamless="seamless"
        allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture"
      ></iframe>
    {{/if}}
  </template>
}
