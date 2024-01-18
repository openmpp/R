# Using openM++ from R

This repository is a part of [OpenM++](http://www.openmpp.org/) open source microsimulation platform.
It contains two independent implementations of R tools for openM++ models:
* `oms-R`: how-to use examples and small set of helper functions to use R on local PC or in cloud.
* `openMpp`: R package which allow read and update openM++ model database on your local computer.

There is also an excelent R package created by Matthew T. Warkentin available at: [oncology-outcomes/openmpp](https://github.com/oncology-outcomes/openmpp).


## `oms-R`: How to use R and `oms` web-service to run the models on local computer

In order to use it on your local desktop please do:
* download openM++ release from https://github.com/openmpp/main/releases/latest
* unpack it into any directory
* start `oms` web-service:
  * on Windows:
  ```
  cd C:\my-openmpp-release
  bin\ompp_ui.bat
  ```
  * on Linux or MacOS:
  ```
  cd ~/my-openmpp-release
  bin/oms
  ```

There are few examples in `oms-R` part of that repository.
Those examples are using small set of helper functions by including it as:
```
source("~/omsCommon.R")
```
Above is assuming you have `omsCommon.R` file in your `$HOME` directory, on Windows `HOME` directory is: `C:\Users\Your-Name-Here\Documents`.
This file is included in every openM++ release as `ompp-r/oms-R/omsCommon.R`, please copy it into your `$HOME` directory.
If you don't have `omsCommon.R` then download it from https://github.com/openmpp/R , go to `oms-R` folder and click on `omsCommon.R`.
If want to put `omsCommon.R` in any other location then update path `~/omsCommon.R` with your actual directory, e.g.: `my-R-is-here/omsCommon.R`.

You don't have to use anything from `omsCommon.R` file, for example you can replace function call of:
```
apiUrl <- getOmsApiUrl()
```
with hard coded value:
```
apiUrl <- "http://localhost:4040/api/"
```
and that would work on your local computer.

Also please consult our wiki for [oms API details.](https://github.com/openmpp/openmpp.github.io/wiki/Oms-web-service) .


## `oms-R`: How to use R to run the models on in cloud

You can run openM++ models in cloud from your local computer RStudio.

Please do following:
* create `.Renviron` file in your `HOME` directory with your cloud credentials:
```
OM_CLOUD_URL=https://cloud-url.openmpp.org
OM_CLOUD_USER=demo
OM_CLOUD_PWD=secret-password
```
**Security warning:** `.Renviron` file is not the safe place to store passwords, use it only if your local PC hard drive protected by encryption.

* copy `omsCommon.R` file in your `$HOME` directory

On Windows `HOME` directory is: `C:\Users\Your-Name-Here\Documents`.
`omsCommon.R` file included in every openM++ release as `ompp-r/oms-R/omsCommon.R`.
If you don't have `omsCommon.R` then download it from https://github.com/openmpp/R , go to `oms-R` folder and click on `omsCommon.R`.

Use `ompp-r/oms-R/riskpaths_childlessness-cloud.R` example to write your own R script and run it from your local computer RStudio.
For example:
```
library("jsonlite")
library("httr")

source("~/omsCommon.R")

# login to cloud workspace

lg <- loginToOpenmCloud()
apiUrl <- lg$apiUrl
loginToken <- lg$loginToken

# get list of the models

rsp <- GET(
    paste0(
      apiUrl, "model-list"
    ),
    set_cookies(jwt_token = loginToken)
  )
if (http_type(rsp) != 'application/json') {
  stop("Failed to get first run status")
}
allModels <- content(rsp)
```

Also please consult our wiki for [oms API details.](https://github.com/openmpp/openmpp.github.io/wiki/Oms-web-service) .


## `openMpp`: Install and use openMpp R package

OpenMpp package tested only with R up to version 3.6.3, please use above `oms` web-service API if you need additiomal functionality.

Download [latest openMpp R package release](https://github.com/openmpp/r/releases/latest) and install:
```
install.packages("~/openMpp_N.N.N.tar.gz", repos = NULL, type = "source")
library(DBI)
library("openMpp")
library("RSQLite")
```

Download [latest openM++ release](https://github.com/openmpp/main/releases/latest), unpack it and `setwd()` to models directory:
```
setwd("~/openmpp_win_20210209/models/bin")
```

Examples can be found at: [R / openMpp / inst/ ](https://github.com/openmpp/R/tree/master/openMpp/inst)

Above examples are also documented at our wiki:

- life_vs_mortality_test.R: [analyze DurationOfLife using MortalityHazard parameter](https://github.com/openmpp/openmpp.github.io/wiki/Run-Model-from-R)
- riskpaths_childlessness.R: [analyze contribution of delayed union formations versus decreased fertility on childlessness](https://github.com/openmpp/openmpp.github.io/wiki/Run-RiskPaths-Model-from-R)


## Build openMpp R package from sources

```
R CMD build openMpp

install.packages("RSQLite")
install.packages("~/openMpp_N.N.N.tar.gz", repos = NULL, type = "source")
```

As it is today only SQLite databases supported. 
For other vendors (Microsoft SQL, MySQL, PostgreSQL, IBM DB2, Oracle) only select from databse tested, update not implemented.

Please check openMpp package `man` documentation and `inst` examples.
Also visit our [wiki](https://github.com/openmpp/openmpp.github.io/wiki) for more information.

## Screenshots

**NewCaseBased** model:  loop over MortalityHazard parameter to analyze DurationOfLife output value.

![Example of NewCaseBased model run.](/images/RStudio_NewCaseBased_oms_2022-06-16.png "Example of NewCaseBased model run.")

**RiskPaths** model: analyze contribution of delayed union formations versus decreased fertility on childlessness.

![Example of RiskPaths model run.](/images/RStudio_RiskPaths_oms_2022-06-16.png "Example of RiskPaths model run.")

**.Renviron** file: how to do it on Windows

![Create .Renviron file.](/images/R_cloud_renviron_file_2023-11-03.png "Create .Renviron file.")

![Verify cloud login settings.](/images/R_cloud_check_env_2023-11-03.png "Verify cloud login settings.")

**Important**: Clear console and clear history after checking your login name and password.

License: MIT.

E-mail: _openmpp dot org at gmail dot com_
