import ImageUploader from "discourse/components/image-uploader";

export default ImageUploader.extend({
  layoutName: "components/image-uploader",

  uploadUrlParams() {
    return "&for_site_setting=true";
  }
});
