
export default Em.Component.extend({
  fileInput: null,
  loading: false,
  expectedRootObjectName: null,
  hover: 0,

  classNames: ['json-uploader'],

  _initialize: function() {
    const $this = this.$();
    const self = this;

    const $fileInput = $this.find('#js-file-input');
    this.set('fileInput', $fileInput[0]);

    $fileInput.on('change', function() {
      self.fileSelected(this.files);
    });

    $this.on('dragover', function(e) {
      if (e.preventDefault) e.preventDefault();
      return false;
    });
    $this.on('dragenter', function(e) {
      if (e.preventDefault) e.preventDefault();
      self.set('hover', self.get('hover') + 1);
      return false;
    });
    $this.on('dragleave', function(e) {
      if (e.preventDefault) e.preventDefault();
      self.set('hover', self.get('hover') - 1);
      return false;
    });
    $this.on('drop', function(e) {
      if (e.preventDefault) e.preventDefault();

      self.set('hover', 0);
      self.fileSelected(e.dataTransfer.files);
      return false;
    });

  }.on('didInsertElement'),

  accept: function() {
    return ".json,application/json,application/x-javascript,text/json" + (this.get('extension') ? "," + this.get('extension') : "");
  }.property('extension'),

  setReady: function() {
    let parsed;
    try {
      parsed = JSON.parse(this.get('value'));
    } catch (e) {
      this.set('ready', false);
      return;
    }

    const rootObject = parsed[this.get('expectedRootObjectName')];

    if (rootObject !== null && rootObject !== undefined) {
      this.set('ready', true);
    } else {
      this.set('ready', false);
    }
  }.observes('destination', 'expectedRootObjectName'),

  actions: {
    selectFile: function() {
      const $fileInput = $(this.get('fileInput'));
      $fileInput.click();
    }
  },

  fileSelected(fileList) {
    const self = this;
    let files = [];
    for (let i = 0; i < fileList.length; i++) {
      files[i] = fileList[i];
    }
    const fileNameRegex = /\.(json|txt)$/;
    files = files.filter(function(file) {
      if (fileNameRegex.test(file.name)) {
        return true;
      }
      if (file.type === "text/plain") {
        return true;
      }
      return false;
    });
    const firstFile = fileList[0];

    this.set('loading', true);

    let reader = new FileReader();
    reader.onload = function(evt) {
      self.set('value', evt.target.result);
      self.set('loading', false);
    };

    reader.readAsText(firstFile);
  }

});
