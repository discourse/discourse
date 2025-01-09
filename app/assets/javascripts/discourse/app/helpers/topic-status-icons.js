const TopicStatusIcons = new (class {
  entries = [];

  addObject(entry) {
    // DEPRECATE
    const [attribute, iconName, titleKey] = entry;
    this.entries.push({ attribute, iconName, titleKey });
  }
})();

export default TopicStatusIcons;
