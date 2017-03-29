# IIS Developer Project Setup Tool
This is intended for use by development teams for creating full tiered applications with one click.
____
## Usage

To immediately start working, download the files in /build and /doc, edit the JSON file (file name must be SiteList.json), right click the exe and run as administrator.

Under /doc you will see an example JSON file of how everything should be set up in order to make the site structure below:

```
dev.newproject.com
│   /auth
│   /webapi
│
└───subsite
        /web
        /webapi

biz.newproject.com
    /newproject

dat.newproject.com
    /newproject

```
