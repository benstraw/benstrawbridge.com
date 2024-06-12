+++
title = 'Screenshot-a-Day'
date = 2024-05-20T13:50:27-07:00
# draft = true
# summary = "screenshotaday service. takes a screen shot every _n_ units of time and adds a frame to a gif which you can host"
homeFeatureIcon = "fa-solid fa-mobile-screen"
+++

## S.A.D. :weary:

> You can’t automate a SLO for look and feel. Or can you?

Screenshot-a-day service. takes a screen shot every _n_ units of time and adds a frame to a gif which you can host.

<!--more-->

Screenshot-a-day is a SaaS application which will be configurable with 3 options: url, interval and dimensions. It will open a web browser in a headless environment (configurable to be a browser or device) running puppateer or similar and load the url at time and take a screenshot of the window at the set dimensions. It will then save this screenshot as 1 image with the timestamp attached the the filename, and add it to a frame at the end of a perpetual animated gif showing the progression of the change over time.

**Price**: $10/year

## App

### Comparison Feature

Select 2 or more historical images and compare them in a variety of ways
- side by side
- overlaied with opacity variability
- cryptographic hash
- .... 

### Settings

Admin interface to set the configurations variables.

- url
- interval
- dimensions
- environment
  - platform
  - browser
  - custom app

## Feedback

how many times have you seen the team deploy change, look at the site and then start arguing about whether or not it looks the same as it did before the deploy?

> “ does this site look the same as yesterday?” 
>  -- <cite>is a question that most orgs cannot answer!</cite>

$10 a year is in a range where a developer can just sign up for it on their personal card. 

Because this is a problem management does not understand.

## Example Workflow on AWS:

1. **Lambda Function:** Hosts the Puppeteer script.
2. **CloudWatch Event Rule:** Triggers the Lambda function at specified intervals.
3. **S3 Bucket:** Stores the screenshots.
4. **API Gateway:** (Optional) Allows users to configure settings.
5. **Amplify:** (Optional) Host settings app.
6. **DynamoDB:** (Optional) Store customer settings to allow for storing change history.

