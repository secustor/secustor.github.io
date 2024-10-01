---
title: "Backstage: Debugging Jest tests"
date: 2024-03-24T00:05:24+02:00
type: post
showToc: true
tags:
  - blog
  - backstage
  - webstorm
  - jest
---
## Jest

This will be a short blog how to set up your Webstorm instance to debug Backstage and its Jest tests.
If you are getting `Jest encountered an unexpected token` on a Backstage repo while debugging with Webstorm.

1. Run configurations
   ![run-configs](./images/run-configs.png)

2. "Edit configurations..."
   ![edit-configuration](./images/edit-config.png)

3. "Edit configuration templates"
   ![edit-template](./images/edit-template.png)

4. "Jest"
   ![jest](./images/jest.png)

5. Add the following test "Jest options"

    ```text title="Jest options"
    --config node_modules/@backstage/cli/config/jest.js
    ```

   This will use the jest config, also used by `backstage-cli`.
   ![options](./images/options.png)

6. Ensure that the working directory is set to that directory which contains root `package.json`

With that, you are good to go!
