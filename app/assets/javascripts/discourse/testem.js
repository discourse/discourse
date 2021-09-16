module.exports = {
  test_page: "tests/index.html?hidepassed",
  disable_watching: true,
  launch_in_ci: ["Chrome", "Firefox", "Headless Firefox"], // Firefox is old ESR version, Headless Firefox is up-to-date evergreen version
  launch_in_dev: ["Chrome"],
  tap_failed_tests_only: true,
  parallel: 1, // disable parallel tests for stability
  browser_args: {
    Chrome: [
      // --no-sandbox is needed when running Chrome inside a container
      process.env.CI || process.env.EMBER_CLI ? "--no-sandbox" : null,
      "--headless",
      "--disable-dev-shm-usage",
      "--disable-software-rasterizer",
      "--mute-audio",
      "--remote-debugging-port=4201",
      "--window-size=1440,900",
    ].filter(Boolean),
    Firefox: ["-headless", "--width=1440", "--height=900"],
    "Headless Firefox": ["--width=1440", "--height=900"],
  },
  browser_paths: {
    "Headless Firefox": "/opt/firefox-evergreen/firefox",
  },
};
