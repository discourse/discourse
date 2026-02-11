---
title: Using Google's 'tachometer' to measure JS performance changes in Discourse
short_title: JS performance
id: js-performance
---

When working on client-side work in Discourse core/plugins/themes, it's important to consider the performance impact. Google's 'Tachometer' project provides a statistically rigorous benchmarking tool which we can use to definitively measure the effect of changes.

https://github.com/google/tachometer

Essentially, this tool takes a list of URLs and loads them in a 'round-robin' fashion. For each page load, it takes some performance measurement. After hundreds/thousands of iterations, it produces a comparison table.

The beauty of this 'round-robin' approach is that it helps to reduce the impact of external factors on measurements.

## Step 1: Add `performance.measure()`

The approach here will vary based on what you're testing. But fundamentally: you need to introduce a `performance.measure()` value for Tachometer to read.

If you want to render the time it takes for Discourse to boot and render, you can use the built-in "discourse-init-to-paint" measurement. For anything else, you can introduce your own `performance.measure` and use that.

You can check it's working using the performance tab in your browser dev tools:

![SCR-20240529-rlhj|690x98, 50%](/assets/js-performance-1.png)

If you're trying to measure an activity which requires user interaction (e.g. opening a menu), you could achieve this by adding something like this in an initializer to click the button 1 second after the page is loaded:

```js
setTimeout(() => document.querySelector(".my-button").click(), 1000);
```

## Step 2: Identify URLs for testing

Firstly, make sure that you are building Ember assets in production mode. This can be achieved by launching the server with `EMBER_ENV=production`.

To obtain two different URLs, there are two main approaches:

If your change is small enough to be easily feature-flagged, then you could add logic to toggle it based on a **URL query parameter**. Then your two urls could be

```
http://localhost:4200?flag=before
http://localhost:4200?flag=after
```

If the change is too large for that, then you could clone Discourse into a second directory and launch a **second copy of ember-cli**. It can be proxied to the same Rails server using a command like

```sh
EMBER_ENV=production pnpm ember serve --port 4201 --proxy http://localhost:3000
```

And then your two URLs would be

```
http://localhost:4200
http://localhost:4201
```

If you take this approach, make sure that both copies of the app have the performance telemetry you introduced in step 1 of this guide

## Step 3: Configure Tachometer

This is my `bench.json` file, which will take 300 samples of each target:

```json
{
  "timeout": 5,
  "sampleSize": 300,
  "benchmarks": [
    {
      "measurement": {
        "mode": "performance",
        "entryName": "discourse-init-to-paint"
      },
      "expand": [
        {
          "url": "http://localhost:4200",
          "name": "before"
        },
        {
          "url": "http://localhost:4201",
          "name": "after"
        }
      ]
    }
  ]
}
```

## Step 4: Run benchmark

To reduce noise, stop any unrelated activities on your workstation, and then start the benchmark with a command like:

```sh
npx tachometer@latest --config ./bench.json
```

When complete, you should see a comparison of the before/after performance.

![image|690x189](/assets/js-performance-2.png)

## Caveats

As with any experiments like this, it's worth considering the limitations. For example:

- Performance differences on your development workstation may not map directly onto other browsers/devices

- The boot process of Discourse through the Ember-CLI proxy is not exactly the same as it is in production. When making structural changes (e.g. framework updates) this may be important

- Performance often varies based on application state (e.g. the number of topics being rendered), so your results may not be exactly reproducible in other environments
