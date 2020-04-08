import ImageUploader from "discourse/components/image-uploader";

export default ImageUploader.extend({
  layoutName: "components/image-uploader",
  uploadUrlParams: "&for_site_setting=true"
});
