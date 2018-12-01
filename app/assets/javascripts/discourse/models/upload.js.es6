import { ajax } from "discourse/lib/ajax";

const Upload = Discourse.Model.extend({
});

Upload.reopenClass({
  findAll() {
    return ajax("/admin/uploads.json").then(result => {
      return {
        uploads_free: result.admin_uploads.uploads_free,
        uploads_used: result.admin_uploads.uploads_used,
        uploads: result.admin_uploads.uploads.map(upload => Upload.create(upload)),
      };
    }
    );
  },
});

export default Upload;
